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
  class NotEnoughData < StandardError; end

  module Mixins
    module IOReactor
      # Read mixin for IOReactor
      module Read
        def handle_read
          begin
            do_read
          rescue EOFError, IOError, Errno::ECONNRESET => e
            read_exception e
          end

          handle_data
          nil
        end

        def handle_data
          @was_read_full = read_full?
          process unless @read_buffer.empty?
          nil
        rescue NotEnoughData
          return send_eof if @eof_scheduled

          # Allow overfilling of the read buffer in the event read(>=4096) was
          # called
          reschedule_read true
        else
          return send_eof if @eof_scheduled && @read_buffer.empty?

          reschedule_read
        end

        def read(n)
          raise 'Socket is not attached' unless @attached
          raise IOError, 'Socket is closed' if @io.closed?
          raise NotEnoughData, 'Not enough data', nil if @read_buffer.length < n

          @read_buffer.read(n)
        end

        def discard
          @read_buffer.reset
          nil
        end

        # Pause read processing
        # Takes effect on the next reschedule, which occurs after each read
        # processing takes place
        def pause
          log_debug 'pause read'
          @pause = true
          nil
        end

        # Resume read processing
        def resume
          log_debug 'resume read'
          @pause = false
          reschedule_read
          nil
        end

        def read_full?
          # TODO: Make read buffer max customisable?
          @read_buffer.length >= 4096
        end

        protected

        def do_read
          read_action
        rescue IO::WaitReadable, Errno::EINTR, Errno::EAGAIN
          return
        end

        def send_eof
          unless @exception.nil?
            exception @exception if respond_to(:exception)
            force_close
            return
          end

          eof if respond_to?(:eof)
          close
          nil
        end

        # To balance threads, process is allowed to return without processing
        # all data, and will get called again after one round even if read not
        # ready again. This allows us to spread processing more evenly if the
        # processor is smart
        # If the read buffer is >=4096 we can also skip read polling otherwise
        # we will add another 4096 bytes and not process it as fast as we are
        # adding the data
        # Also, allow the processor to pause read which has the same effect -
        # it is expected a timer or something will then resume read - this can
        # be if the client is waiting on a background thread
        # NOTE: Processor should be careful, if it processes nothing this can
        #       cause a busy loop
        def reschedule_read(overfill = false)
          if @pause
            @multiplexer.stop_read self
            return
          end

          if read_full? && !overfill
            # Stop reading, the buffer is too full, let the processor catch up
            log_info 'Holding read due to full read buffer'
            @multiplexer.stop_read self
            @multiplexer.defer self
            return
          end

          # Only schedule read if write isn't full - this allows us to drain
          # write buffer before reading again and prevents a client from sending
          # large amounts of data without receiving responses
          if @w && write_full?
            log_info 'Holding read due to full write buffer'
            @multiplexer.stop_read self
            return
          end

          schedule_read
        end

        # Schedules the next read action, can be overrided if necessary to
        # change how the next read should be scheduled
        def schedule_read
          @multiplexer.defer self unless @read_buffer.empty?

          # Resume read signal if we had paused due to full buffer
          @multiplexer.wait_read self if @was_read_full
        end

        # Can be overridden for other IO objects
        def read_nonblock(n)
          log_debug 'read_nonblock', count: n
          @io.read_nonblock(n)
        end

        # Can be overriden for other IO objects
        def read_action
          @read_buffer << read_nonblock(4096)
          nil
        end

        def read_exception(e)
          @eof_scheduled = true
          @exception = e unless e.is_a?(EOFError)
          @multiplexer.stop_read self
        end
      end # ::Read
    end # ::IOReactor
  end # ::Mixins
end # ::IOMultiplex
