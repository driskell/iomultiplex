require 'nio'

module IOMultiplex
  module Mixins
    # IO Select mixin
    # Depends on Mixins::State
    module Select
      def wait_read(client)
        set_wait client, State::STATE_WAIT_READ, true
      end

      def wait_write(client)
        set_wait client, State::STATE_WAIT_WRITE, true
      end

      def stop_read(client)
        set_wait client, State::STATE_WAIT_READ, false
      end

      def stop_write(client)
        set_wait client, State::STATE_WAIT_WRITE, false
      end

      def stop_all(client)
        state = must_get_state(client)
        return if \
          state & (State::STATE_WAIT_READ | State::STATE_WAIT_WRITE) == 0

        state = remove_state client,
                             State::STATE_WAIT_READ | State::STATE_WAIT_WRITE
        update_select client, state
      end

      protected

      def initialize_select(options)
        setup_select_logslow options if options[:log_slow]

        @nio = NIO::Selector.new
      end

      def set_wait(client, flag, desired)
        state = must_get_state(client)

        if desired
          return unless state & flag == 0
          state = add_state(client, flag)
        else
          return if state & flag == 0
          state = remove_state(client, flag)
        end

        update_select client, state
        nil
      end

      def update_select(client, state)
        @nio.deregister client.io

        if state & State::STATE_WAIT_READ == 0 &&
           state & State::STATE_WAIT_WRITE == 0
          log_debug 'NIO::Select interest updated',
                    :client => client.id, :interests => nil
          return
        elsif state & State::STATE_WAIT_READ == 0
          interests = :w
        elsif state & State::STATE_WAIT_WRITE == 0
          interests = :r
        else
          interests = :rw
        end

        monitor = @nio.register(client.io, interests)
        monitor.value = client
        log_debug 'NIO::Select interest updated',
                  :client => client.id, :interests => interests
      end

      def select_io(timeout)
        log_debug 'NIO::Select enter', :timeout => timeout

        @nio.select(timeout) do |monitor|
          next if get_state(monitor.value).nil?
          if monitor.readable?
            log_debug 'NIO::Select signalling',
                      :what => :read, :client => monitor.value.id
            monitor.value.handle_read
          end

          # Check we didn't remove the socket before we call monitor.writable?
          # otherwise it will throw a Java CancelledKeyException wrapped in
          # NativeException because we tried to access a removed monitor
          next if get_state(monitor.value).nil? || !monitor.writable?
          log_debug 'NIO::Select signalling',
                    :what => :write, :client => monitor.value.id
          monitor.value.handle_write
        end
        nil
      end

      def setup_select_logslow
        require 'iomultiplex/logslow.rb'
        class <<self
          extend LogSlow

          private

          alias_method :_orig_select_io, :select_io
          define_method :select_io do |next_timer|
            log_slow _orig_select_io, [next_timer], 100, _select_io_diagnostics
          end

          define_method :_select_io_diagnostics do
            timeout = next_timer
            if timeout.nil?
              timer_due = 'None'
              timer_delay = 'N/A'
            else
              timer_due = timeout.to_f.ceil
              timer_delay = now > timer ? ((now - timeout) * 1000).to_i : 'None'
            end
            { :timer_due => timer_due, :timer_delay => timer_delay }
          end
        end # <<self
        nil
      end
    end # ::Select
  end # ::Mixins
end # ::IOMultiplex
