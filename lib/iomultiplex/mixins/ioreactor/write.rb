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

module IOMultiplex
  module Mixins
    module IOReactor
      # Write mixin for IOReactor
      module Write
        def handle_write
          if @write_buffer.length == 0
            @multiplexer.stop_write self
            @write_immediately = true
            return
          end

          begin
            do_write
          rescue IO::WaitWritable, Errno::EINTR, Errno::EAGAIN
            # Keep waiting for write
            return
          rescue IOError, Errno::ECONNRESET, OpenSSL::SSL::SSLError => e
            exception e if respond_to?(:exception)
            force_close
          end

          nil
        end

        def write(data)
          fail 'Socket is not attached' unless @attached
          fail IOError, 'Socket is closed' if @io.closed?

          @write_buffer.push data
          @multiplexer.wait_write self

          if @write_immediately
            handle_write
            @write_immediately = false
          end

          # Write buffer too large - pause read polling
          if write_full?
            log_debug 'write buffer full, pausing read',
                      count: @write_buffer.length
            @multiplexer.stop_read self
            @multiplexer.remove_post self
          end
          nil
        end

        def write_full?
          # TODO: Make write buffer max customisable?
          @write_buffer.length >= 16 * 1024
        end

        protected

        def do_write
          was_write_full = write_full?
          @write_buffer.shift write_action

          if @write_buffer.length == 0
            force_close if @close_scheduled
          elsif was_write_full && !write_full? && !@pause
            log_debug 'write buffer no longer full, resuming read',
                      count: @write_buffer.length
            reschedule_read
          end
        end

        # Can be overridden for other IO objects
        def write_nonblock(data)
          log_debug 'write_nonblock', count: data.length
          @io.write_nonblock(data)
        end

        # Can be overriden for other IO objects
        def write_action
          write_nonblock @write_buffer.peek(4096)
        end
      end # ::Write
    end # ::IOReactor
  end # ::Mixins
end # ::IOMultiplex
