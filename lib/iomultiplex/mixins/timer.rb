module IOMultiplex
  module Mixins
    # Timer handling methods
    # Depends on Mixins::State
    # TODO: We should use monotonic clock here!
    module Timer
      def add_timer(timer, at)
        fail ArgumentError, 'Timer must response to "timer"' \
          unless timer.respond_to? :timer

        state = get_state(timer)
        remove_timer_state timer, true if state && state & LOOKUP_TIMER != 0
        j = -1
        @timers.length.step(2) do |i|
          if @timers[i] > at
            j = i
            break
          end
        end
        @timers.insert j, at, timer
        set_state timer, LOOKUP_TIMER
        nil
      end

      def remove_timer(timer)
        state = must_get_state(timer)
        return unless state & LOOKUP_TIMER != 0

        remove_timer_state timer, true
        nil
      end

      protected

      # Trigger available timers
      def trigger_timers
        return if @timers.empty?

        now = Time.now

        while @timers.length != 0
          break if @timers[0].time > now
          @timers.shift
          timer = @timers.shift
          remove_timer timer, false
          timer.timer
        end

        nil
      end

      # Remove a timer from the internal state
      def remove_timer_state(timer, cancel)
        if cancel
          @timers.length.step(2) do |i|
            if @timers[i + 1] == timer
              @timers.slice! i, 2
              break
            end
          end
        end

        state = remove_state(timer, LOOKUP_TIMER)
        deregister_state timer if state == 0
        nil
      end
    end # ::Timer
  end # ::Mixins
end # ::IOMultiplex
