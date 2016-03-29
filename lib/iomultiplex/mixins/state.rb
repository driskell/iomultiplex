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
    # State handling methods
    module State
      protected

      STATE_REGISTERED = 0
      STATE_WAIT_READ = 1
      STATE_WAIT_WRITE = 2
      STATE_TIMER = 4

      def initialize_state
        @lookup = Hash.new do |h, k|
          h[k] = STATE_REGISTERED
        end
      end

      # Returns the state for a given client or throws an exception if it
      # isn't registered
      def must_get_state(client)
        lookup = get_state client
        raise ArgumentError, 'Client is not registered' if lookup.nil?
        lookup
      end

      # Return the state for a given client
      # Returns nil if the client is not registered
      def get_state(client)
        @lookup.key?(client) ? @lookup[client] : nil
      end

      # Adds a state flag for a client
      # If the client is not registered, creates a registration
      def add_state(client, flag)
        @lookup[client] |= flag
      end

      # Removes a state flag for a client
      # If the client is not registered, creates a registration
      def remove_state(client, flag)
        @lookup[client] ^= flag
      end

      # Register a client
      def register_state(client)
        raise ArgumentError, 'Client is already registered' if get_state(client)
        @lookup[client]
      end

      # Deregister a client
      def deregister_state(client)
        @lookup.delete client
      end

      # Loop registered clients (non-timer clients)
      def each_registered_client
        @lookup.each do |client, state|
          yield client unless state & STATE_REGISTERED == 0
        end
      end
    end # ::State
  end # ::Mixins
end # ::IOMultiplex
