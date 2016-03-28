require 'nio'

module IOMultiplex
  module Mixins
    # IO Select mixin
    # Depends on Mixins::State
    module Select
      def wait_read(client)
        set_wait client, STATE_WAIT_READ, true
      end

      def wait_write(client)
        set_wait client, STATE_WAIT_WRITE, true
      end

      def stop_read(client)
        set_wait client, STATE_WAIT_READ, false
      end

      def stop_write(client)
        set_wait client, STATE_WAIT_WRITE, false
      end

      def stop_all(client)
        state = must_get_state(client)
        return if state & (STATE_WAIT_READ | STATE_WAIT_WRITE) == 0

        state = remove_state client, STATE_WAIT_READ | STATE_WAIT_WRITE
        update_select client, state
      end

      protected

      def initialize_select(options)
        return unless options[:log_slow]

        require 'iomultiplex/logslow.rb'
        class <<self
          extend LogSlow

          private

          alias_method :_orig_select_io, :select_io
          define_method :select_io do |next_timer|
            log_slow _orig_select_io, [next_timer], 100, _select_io_diagnostics
          end

          define_method :_select_io_diagnostics do
            if @timers.length == 0
              timer_due = 'None'
              timer_delay = 'N/A'
            else
              timer_due = @timers[0].time.to_f.ceil
              if now > @timers[0].time
                timer_delay = ((now - @timers[0].time) * 1000).to_i
              else
                timer_delay = 'None'
              end
            end
            { :timer_due => timer_due, :timer_delay => timer_delay }
          end
        end
        nil
      end

      def update_select(client, state)
        @nio.deregister client.io

        if state & STATE_WAIT_READ == 0 && state & STATE_WAIT_WRITE == 0
          return
        elsif state & STATE_WAIT_READ == 0
          interests = :w
        elsif state & STATE_WAIT_WRITE == 0
          interests = :r
        else
          interests = :rw
        end

        monitor = @nio.register(client.io, interests)
        monitor.value = client
      end

      def select_io(next_timer)
        @nio.select(next_timer) do |monitor|
          next if get_state(monitor.value).nil?
          monitor.value.handle_read if monitor.readable?

          # Check we didn't remove the socket before we call monitor.writable?
          # otherwise it will throw a Java CancelledKeyException wrapped in
          # NativeException because we tried to access a removed monitor
          next if get_state(monitor.value).nil? || !monitor.writable?
          monitor.value.handle_write
        end
        nil
      end

      def set_wait(client, flag, desired)
        state = must_get_state(client)

        if desired
          return if state & flag == 0
          state = add_state(client, flag)
        else
          return unless state & flag == 0
          state = remove_state(client, flag)
        end

        update_select client, state
        nil
      end
    end # ::Select
  end # ::Mixins
end # ::IOMultiplex
