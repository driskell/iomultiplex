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
  class NotEnoughData < StandardError; end

  module Mixins
    module IOReactor
      # Read mixin for IOReactor
      module Read
        # TODO: Make these customisable?
        READ_BUFFER_MAX = 16_384
        READ_SIZE = 16_384

        ALLOW_OVERFILL = true

        # Handle read availability
        # This is covered over a couple of processes:
        # 1. do_read - Wraps around the read_action to handle WaitReadable and
        #    other normal exceptions and can be overridden to handle other
        #    conditions or logic
        # 2. read_action - Actually performs the read and can be overriden for
        #    different IO types
        # 2. handle_data - Processes available data and decides whether or not
        #    we need to continue listening for read availability or not
        def handle_read
          begin
            do_read
          rescue IOError, Errno::ECONNRESET => e
            read_exception e
          end

          handle_data
          nil
        end

        # Process data and schedule read/defer
        # If process attempted to process more data than we have in the buffer
        # then when it reschedules read it will allow the buffer to overfill
        # Otherwise, read will only continue if the buffer has room
        # This allows the buffer to grow when needed whilst keeping it small
        # whenever possible
        def handle_data
          process unless @read_buffer.empty?
          nil
        rescue NotEnoughData
          return send_eof if @eof_scheduled

          # Allow overfilling of the read buffer in the event
          # read(>=READ_BUFFER_MAX) was called
          reschedule_read ALLOW_OVERFILL
        else
          return send_eof if @eof_scheduled && @read_buffer.empty?

          reschedule_read
        end

        def read(n)
          raise IOError, 'Socket is closed' if @closed
          raise NotEnoughData, 'Not enough data', nil if @read_buffer.length < n

          @read_buffer.read n
        end

        def discard
          @read_buffer.reset
          nil
        end

        # Pause read processing
        # Takes effect on the next reschedule, which occurs after each read
        # processing takes place
        def pause
          return if @pause
          log_debug 'pause read'
          @pause = true
          @was_paused = true
          nil
        end

        # Resume read processing
        def resume
          return unless @pause
          log_debug 'resume read'
          @pause = false
          reschedule_read
          nil
        end

        def read_full?
          @read_buffer.length >= READ_BUFFER_MAX
        end

        protected

        # Perform read_action and handle any expected read exceptions
        def do_read
          read_action
        rescue IO::WaitReadable, Errno::EINTR, Errno::EAGAIN
          return
        end

        def send_eof
          unless @exception.nil?
            exception @exception if respond_to?(:exception)
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
        def reschedule_read(allow_overfill = false)
          if @pause
            @multiplexer.stop_read self
            return
          end

          if read_full? && !allow_overfill
            # Stop reading, the buffer is too full, let the processor catch up
            # by continuously calling handle_data (bypassing handle_read)
            # and handle_data will call reschedule again so we can schedule
            # read again when more data is available
            log_info 'Holding read due to full read buffer'
            @multiplexer.stop_read self
            @multiplexer.defer self
            @was_paused = true
            return
          end

          schedule_read
        end

        # Schedules the next read action, can be overrided if necessary to
        # change how the next read should be scheduled
        def schedule_read
          @multiplexer.defer self unless @read_buffer.empty?

          # Resume read signal if we had paused due to full buffer
          if !@exception && @was_paused
            @was_paused = false
            @multiplexer.wait_read self
          end

          nil
        end

        # Can be overridden for other IO objects
        # Default is a regular nonblocking read, but inheriting classes may want
        # to pass this read through a SSL layer
        def read_nonblock(n)
          log_debug 'read_nonblock', count: n
          @io.read_nonblock(n)
        end

        # Can be overridden for other read behaviours
        # Default read action is to... read from IO! Inheriting classes may
        # want to override to handle connect and accept behaviours if the IO
        # is a TCP stream
        def read_action
          @read_buffer << read_nonblock(READ_SIZE)
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
