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
          raise IOError, 'Socket is closed' if @closed

          @write_buffer.push data
          handle_write if @write_immediately
          nil
        end

        def flush
          raise IOError, 'Flush available only in rw mode' unless @r

          return if @write_buffer.empty?

          # Pause read until we have flushed all data
          log_debug 'pausing read to flush write buffer',
                    count: @write_buffer.length
          @multiplexer.stop_read self
          @multiplexer.remove_post self
          @flush_in_progress = true
        end

        protected

        def do_write
          @write_buffer.shift write_action

          reschedule_write
        rescue IO::WaitWritable, Errno::EINTR, Errno::EAGAIN
          reschedule_write
        end

        def reschedule_write
          unless @write_buffer.empty?
            # Wait for write
            @multiplexer.wait_write self if @write_immediately
            @write_immediately = false
            return
          end

          @multiplexer.stop_write self unless @write_immediately
          @write_immediately = true

          return force_close if @close_scheduled

          flush_complete if @flush_in_progress
        end

        def flush_complete
          log_debug 'write buffer flushed, resuming read'
          @multiplexer.wait_read self
          @flush_in_progress = false
          reschedule_read
        end

        # Can be overridden for other IO objects
        # Default is a regular nonblocking write, but inheriting classes may
        # want to pass this write through a SSL layer
        def write_nonblock(data)
          log_debug 'write_nonblock', count: data.length
          @io.write_nonblock(data)
        end

        # Can be overridden for other write behaviours
        # Default write action is to... write to IO! Inheriting classes may
        # want to override to handle connect and accept behaviours if the IO
        # is a TCP stream
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
