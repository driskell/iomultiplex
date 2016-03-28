module IOMultiplex
  module Mixins
    # Logger provides ability for object specific context in logs
    module Logger
      attr_reader :logger
      attr_reader :logger_context

      protected

      def initialize_logger(logger = nil, logger_context = nil)
        @logger = logger || Cabin::Channel.get(IOMultiplex)
        @logger_context = logger_context.nil? ? {} : logger_context
      end

      def add_logger_context(key, value)
        @logger_context[key] = value
      end

      def clear_logger_context
        @logger_context = nil
      end

      %w(fatal error warn info debug).each do |level|
        method = ('log_' + level).to_sym
        level = level.to_sym

        define_method(method) do |*args|
          args[1] ||= {}

          unless args[1].is_a?(Hash)
            raise ArgumentError 'Second argument must be a hash'
          end

          args[1].merge! @logger_context unless @logger_context.nil?
          @logger.send(level, *args)
        end
      end
    end # ::Logger
  end # ::Mixins
end # ::IOMultiplex
