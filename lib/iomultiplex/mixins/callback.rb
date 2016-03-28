module IOMultiplex
  module Mixins
    # Callback methods
    # Depends on Mixins::State
    module Callback
      # Run a callback on the IO thread
      # Can be safely triggered from any thread
      def callback(&block)
        @callbacks.push block
        @nio.wakeup
        nil
      end

      protected

      def initialize_callbacks
        @callbacks = []
      end

      def trigger_callbacks
        return if @callbacks.empty?
        @callbacks.each(&:call)
        @callbacks = []
        nil
      end
    end # ::Callback
  end # ::Mixins
end # ::IOMultiplex
