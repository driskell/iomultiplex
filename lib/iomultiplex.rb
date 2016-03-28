# encoding: utf-8

# Copyright 2014 Jason Woods.
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

require 'cabin'
require 'iomultiplex/cabin-copy'
require 'iomultiplex/ioreactor'
require 'iomultiplex/mixins/callback'
require 'iomultiplex/mixins/logslow'
require 'iomultiplex/mixins/select'
require 'iomultiplex/mixins/state'
require 'iomultiplex/mixins/timer'
require 'iomultiplex/stringbuffer'
require 'iomultiplex/tcplistener'

module IOMultiplex
  # A single multiplexer that can process hundreds of clients in a single thread
  class Multiplexer
    include Mixins::Logger
    include Mixins::State
    include Mixins::Select
    include Mixins::Callback
    include Mixins::Timer

    def initialize(options = {})
      initialize_state
      initialize_select options
      initialize_logger options[:logger], options[:logger_context]

      @id = options[:id] || object_id
      add_logger_context 'multiplexer', @id
      nil
    end

    def run
      run_once until @shutdown

      log_debug 'Shutdown'

      # Forced shutdown
      each_registered_client(&:force_close)
      nil
    end

    def add(client)
      fail ArgumentError,
           'Client must be an instance of IOMultiplex::IOReactor' \
           unless client.is_a? IOReactor
      fail ArgumentError,
           'Client is already attached' \
           unless get_state(client).nil?

      client.attach self
      register_state client

      @mutex.synchronize do
        @connections += 1
      end
      nil
    end

    def remove(client)
      state = must_get_state(client)

      @mutex.synchronize do
        @connections -= 1
      end

      client.detach
      stop_all client
      remove_post client
      remove_timer client

      # If not timer-only, deregister (timers are deregistered by remove_timer)
      deregister_state client if state ^ LOOKUP_TIMER != 0
      nil
    end

    def connections
      @mutex.synchronize do
        @connections
      end
    end

    def shutdown
      @shutdown = true
      @nio.wakeup
      nil
    end

    protected

    def run_once
      # If post processing is scheduled, do not block on select
      # Otherwise, only block until next timer
      # And if no timers, bock indefinitely
      next_timer = nil
      if schedule_post_processing
        next_timer = 0
      elsif @timers.length != 0
        next_timer = (@timers[0].time - Time.now).ceil
        next_timer = 0 if next_timer < 0
      end

      select_io next_timer

      # Trigger callbacks and timers
      trigger_callbacks
      trigger_timers

      trigger_post_processing
    end
  end
end
