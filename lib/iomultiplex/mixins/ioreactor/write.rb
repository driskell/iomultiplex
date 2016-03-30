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
    module IOReactor
      # Write mixin for IOReactor
      module Write
        # TODO: Make these customisable?
        WRITE_BUFFER_MAX = 16_384
        WRITE_SIZE = 4_096

        def handle_write
          begin
            do_write
          rescue IOError, Errno::ECONNRESET => e
            write_exception e
          end

          nil
        end

        def write(data)
          raise 'Socket is not attached' unless @attached
          raise IOError, 'Socket is closed' if @io.closed?

          @write_buffer.push data
          handle_write if @write_immediately

          # Write buffer too large - pause read polling
          if @r && write_full?
            log_debug 'write buffer full, pausing read',
                      count: @write_buffer.length
            @multiplexer.stop_read self
            @multiplexer.remove_post self
          end
          nil
        end

        def write_full?
          @write_buffer.length >= WRITE_BUFFER_MAX
        end

        protected

        def reading?
          @r && !@pause
        end

        def do_write
          @was_read_held = reading? && write_full?
          @write_buffer.shift write_action

          if @write_buffer.empty?
            force_close if @close_scheduled
            return
          end

          check_read_throttle
        rescue IO::WaitWritable, Errno::EINTR, Errno::EAGAIN
          # Wait for write
          @write_immediately = false
          @multiplexer.wait_write self
        else
          @write_immediately = true
          @multiplexer.stop_write self
        end

        def check_read_throttle
          return unless @was_read_held && !write_full?

          log_debug 'write buffer no longer full, resuming read',
                    count: @write_buffer.length
          @multiplexer.wait_read self
          reschedule_read
        end

        # Can be overridden for other IO objects
        def write_nonblock(data)
          log_debug 'write_nonblock', count: data.length
          @io.write_nonblock(data)
        end

        # Can be overriden for other IO objects
        def write_action
          write_nonblock @write_buffer.peek(WRITE_SIZE)
        end

        def write_exception(e)
          exception e if respond_to?(:exception)
          force_close
        end
      end # ::Write
    end # ::IOReactor
  end # ::Mixins
end # ::IOMultiplex
