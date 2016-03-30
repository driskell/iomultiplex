# encoding: utf-8

# Copyright 2014-2016 Jason Woods
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
        exists = state & State::STATE_TIMER != 0
        @timers.delete [@timers_time[timer], timer] if exists

        entry = [at, timer]
        @timers.add entry
        @timers_time[timer] = at

        add_state timer, State::STATE_TIMER unless exists
        nil
      end

      def remove_timer(timer)
        state = must_get_state(timer)
        return unless state & State::STATE_TIMER != 0

        entry = [@timers_time[timer], timer]
        remove_timer_state entry
        nil
      end

      protected

      def initialize_timers
        @timers = SortedSet.new
        @timers_time = {}
      end

      def next_timer
        entry = @timers.first
        entry.nil? ? nil : entry[0]
      end

      # Trigger available timers
      def trigger_timers
        return if @timers.empty?

        now = Time.now
        until @timers.empty?
          entry = @timers.first
          break if entry[0] > now
          remove_timer_state entry
          entry[1].timer
        end

        nil
      end

      # Remove a timer from the internal state
      def remove_timer_state(entry)
        timer = entry[1]
        @timers.delete entry
        @timers_time.delete timer

        state = remove_state(timer, State::STATE_TIMER)
        deregister_state timer if state == 0
        nil
      end
    end # ::Timer
  end # ::Mixins
end # ::IOMultiplex
