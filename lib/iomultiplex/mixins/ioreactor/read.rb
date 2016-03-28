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
          rescue EOFError, IOError, Errno::ECONNRESET,
                 OpenSSL::SSL::SSLError => e
            @eof_scheduled = true
            @exception = e unless e.is_a(EOFError)
            @multiplexer.stop_read self
          end

          handle_data
          nil
        end

        def handle_data
          process if @read_buffer.length != 0
          send_eof if @eof_scheduled && @read_buffer.length == 0
          nil
        rescue NotEnoughData
          # Allow overfilling of the read buffer in the even read(>=4096) was
          # called
          reschedule_read true
        else
          reschedule_read
        end

        def read(n)
          fail 'Socket is not attached' unless @attached
          fail IOError, 'Socket is closed' if @io.closed?
          fail NotEnoughData, 'Not enough data', nil if @read_buffer.length < n

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
          @wait_readable = true
        else
          @wait_readable = false
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
            @multiplexer.stop_read self
            @multiplexer.defer self
            return
          end

          schedule_read
        end

        # Schedules the next read actions, can be overrided if necessary such as
        # by buffered IOReactor to force a read until WaitReadable
        def schedule_read
          # Only schedule read if write isn't full - this allows us to drain
          # write buffer before reading again and prevents a client from sending
          # large amounts of data without receiving responses
          return if write_full?

          @multiplexer.defer self if @read_buffer.length > 0

          # Ensure we're waiting on read in case this was a deferred call
          @multiplexer.wait_read self if @wait_readable
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
      end # ::Read
    end # ::IOReactor
  end # ::Mixins
end # ::IOMultiplex
