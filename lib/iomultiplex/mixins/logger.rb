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
        pmethod = ('log_' + level + '?').to_sym
        logger_method = level.to_sym
        logger_pmethod = (level + '?').to_sym

        define_method(method) do |*args|
          return unless @logger.send(logger_pmethod)

          args[1] ||= {}

          unless args[1].is_a?(Hash)
            raise ArgumentError 'Second argument must be a hash'
          end

          args[1].merge! @logger_context unless @logger_context.nil?
          @logger.send logger_method, *args
        end

        define_method(pmethod) do
          @logger.send logger_pmethod
        end
      end
    end # ::Logger
  end # ::Mixins
end # ::IOMultiplex
