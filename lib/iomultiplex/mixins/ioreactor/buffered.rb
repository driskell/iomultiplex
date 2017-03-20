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

require 'iomultiplex/ioreactor'

module IOMultiplex
  module Mixins
    module IOReactor
      # Implements handling for buffered IO objects
      # When the read signal triggers for the IO object, it will continuously
      # call handle_read in the main loops post processing until it receives a
      # WaitReadable signal. This ensures any data left in the IO buffer after
      # a read is correctly read without waiting for a read signal which is a
      # signal for data on the network, not in the buffer.
      # This is in contrast to normal behaviour, which is to only call
      # handle_read when the read signal happens
      module Buffered
        protected

        # When handling expected exceptions, also pickup WaitReadable and note
        # that it was raised - it is only in this case that we should allow
        # read to scheduled, and in all other cases, force a read
        def do_read
          read_action
        rescue IO::WaitReadable, Errno::EINTR, Errno::EAGAIN
          @wait_readable = true
        else
          @wait_readable = false
        end

        # When scheduling read, check our wait_readable flag, and if we didn't
        # receive a WaitReadable, perform a different behaviour - force a read
        # on the next tick and pretend we were paused (so that when we do hit
        # the normal behaviour it resumes the wait signal, much like we would
        # if we were fully paused)
        def schedule_read
          return super if @wait_readable
          @multiplexer.stop_read self unless @was_paused
          @multiplexer.force_read self
          @was_paused = true
        end
      end # ::Buffered
    end # ::IOReactor
  end # ::Mixins
end # ::IOMultiplex
