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
  class IOReactor
    # Wraps around a buffered IO object
    # When the read signal triggers for the IO object, it will continuously read
    # in the main loops post processing until it receives a WaitReadable signal.
    # This ensures any data left in the IO buffer after a read is correctly read
    # without waiting for a read signal
    class Buffered < IOReactor
      def initialize(io, mode = 'rw', id = nil)
        super io, mode, id
      end

      protected

      def do_read
        read_action
      rescue IO::WaitReadable, Errno::EINTR, Errno::EAGAIN
        @wait_readable = true
      else
        @wait_readable = false
      end

      def schedule_read
        @multiplexer.defer self unless @read_buffer.empty?

        # Keep forcing reads until we hit a WaitReadable, in case there is
        # buffered data in the IO
        if @wait_readable
          @multiplexer.wait_read self
        else
          @multiplexer.stop_read self
          @multiplexer.force_read self
        end
      end
    end # ::Buffered
  end # ::IOReactor
end # ::IOMultiplex
