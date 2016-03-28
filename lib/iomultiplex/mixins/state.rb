module IOMultiplex
  module Mixins
    # State handling methods
    module State
      protected

      STATE_REGISTERED = 0
      STATE_WAIT_READ = 1
      STATE_WAIT_WRITE = 2
      STATE_TIMER = 4
      # 8 - free
      STATE_DEFER = 16
      STATE_FORCE_READ = 32

      def initialize_state
        @lookup = Hash.new do |h, k|
          h[k] = STATE_REGISTERED
        end
      end

      # Returns the state for a given client or throws an exception if it
      # isn't registered
      def must_get_state(client)
        lookup = get_state client
        fail ArgumentError, 'Client is not registered' if lookup.nil?
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
        fail ArgumentError, 'Client is already registered' if _get_state client
        @lookup[client]
      end

      # Deregister a client
      def deregister_state(client)
        @lookup.remove client
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
