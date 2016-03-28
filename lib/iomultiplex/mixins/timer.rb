module IOMultiplex
  module Mixins
    # Timer handling methods
    # Depends on Mixins::State
    # TODO: We should use monotonic clock here!
    module Timer
      def add_timer(timer, at)
        raise ArgumentError, 'Timer must response to "timer"' \
          unless timer.respond_to? :timer

        state = get_state(timer)
        remove_timer_state timer, true if state & State::STATE_TIMER != 0
        j = -1
        unless @timers.empty?
          0.step(@timers.length - 1, 2) do |i|
            next unless @timers[i] > at
            j = i
            break
          end
        end
        @timers.insert j, at, timer
        add_state timer, State::STATE_TIMER
        nil
      end

      def remove_timer(timer)
        state = must_get_state(timer)
        return unless state & State::STATE_TIMER != 0

        remove_timer_state timer, true
        nil
      end

      protected

      def initialize_timers
        @timers = []
      end

      def next_timer
        return nil if @timers.empty?
        @timers[0]
      end

      # Trigger available timers
      def trigger_timers
        return if @timers.empty?

        now = Time.now

        until @timers.empty?
          break if @timers[0] > now
          @timers.shift
          timer = @timers.shift
          remove_timer_state timer, false
          timer.timer
        end

        nil
      end

      # Remove a timer from the internal state
      def remove_timer_state(timer, cancel)
        if cancel && !@timers.empty?
          0.step(@timers.length - 1, 2) do |i|
            if @timers[i + 1] == timer
              @timers.slice! i, 2
              break
            end
          end
        end

        state = remove_state(timer, State::STATE_TIMER)
        deregister_state timer if state == 0
        nil
      end
    end # ::Timer
  end # ::Mixins
end # ::IOMultiplex
