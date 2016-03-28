module IOMultiplex
  module Mixins
    # Post processing - used by OpenSSL etc to force a read until wait required
    # in case there is buffered data
    module Post
      def defer(client)
        post_process client, State::STATE_DEFER
      end

      def force_read(client)
        post_process client, State::STATE_FORCE_READ
      end

      def remove_post(client)
        state = must_get_state(client)
        return if state & (State::STATE_DEFER | State::STATE_FORCE_READ) == 0

        remove_state client, State::STATE_DEFER | State::STATE_FORCE_READ
        @post_processing.delete client
        @scheduled_post_processing.delete client
      end

      protected

      def initialize_post
        @post_processing = []
        @scheduled_post_processing = nil
      end

      def schedule_post_processing
        return false if @post_processing.empty?

        # Run deferred after we finish this loop
        # New defers then carry to next loop
        @scheduled_post_processing = @post_processing
        @post_processing = []
        true
      end

      def trigger_post_processing
        return if @scheduled_post_processing.nil?

        @scheduled_post_processing.each do |client|
          state = get_state client
          next if state.nil?
          force_read = state & State::STATE_FORCE_READ != 0
          remove_state client, State::STATE_DEFER | State::STATE_FORCE_READ
          # During handle_read a handle_data happens so if we have both defer
          # and read we also should use handle_read
          if force_read
            client.handle_read
          else
            client.handle_data
          end
        end

        @scheduled_post_processing = nil
      end

      def post_process(client, flag)
        state = must_get_state(client)

        return if state & flag != 0
        @post_processing.push client
        add_state client, flag
        nil
      end
    end # ::Post
  end # ::Mixins
end # ::IOMultiplex
