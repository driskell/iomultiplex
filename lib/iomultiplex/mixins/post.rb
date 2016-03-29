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
    # Post processing - used by OpenSSL etc to force a read until wait required
    # in case there is buffered data
    module Post
      def defer(client)
        post_process client, POST_DEFER
      end

      def force_read(client)
        post_process client, POST_FORCE_READ
      end

      def remove_post(client)
        @post_processing.delete client
        return if @scheduled_post_processing.nil?
        @scheduled_post_processing.delete client
        nil
      end

      protected

      POST_DEFER = 1
      POST_FORCE_READ = 2

      def initialize_post
        @post_processing = {}
        @scheduled_post_processing = nil
      end

      def schedule_post_processing
        return false if @post_processing.empty?

        # Run deferred after we finish this loop
        # New defers then carry to next loop
        @scheduled_post_processing = @post_processing
        @post_processing = {}
        true
      end

      def trigger_post_processing
        return if @scheduled_post_processing.nil?

        @scheduled_post_processing.each do |client, flag|
          # During handle_read a handle_data happens so if we have both defer
          # and read we also should use handle_read
          if flag & POST_FORCE_READ != 0
            log_debug 'Post processing', :client => client.id, :what => 'read'
            client.handle_read
          else
            log_debug 'Post processing', :client => client.id, :what => 'defer'
            client.handle_data
          end
        end

        @scheduled_post_processing = nil
      end

      def post_process(client, flag)
        current = @post_processing.key?(client) ? @post_processing[client] : nil
        return if !current.nil? && current & flag != 0

        log_debug 'Scheduled post processing',
                  :client => client.id,
                  :what => flag & POST_FORCE_READ != 0 ? 'read' : 'defer'

        @post_processing[client] ||= 0
        @post_processing[client] |= flag
        nil
      end
    end # ::Post
  end # ::Mixins
end # ::IOMultiplex
