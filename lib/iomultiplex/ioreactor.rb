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

require 'iomultiplex/mixins/ioreactor/read'
require 'iomultiplex/mixins/ioreactor/write'

module IOMultiplex
  # IOReactor - reactor style wrapper around IO objects
  class IOReactor
    attr_reader :id
    attr_reader :io
    attr_reader :mode
    attr_reader :peer

    include Mixins::IOReactor::Read
    include Mixins::IOReactor::Write

    def initialize(io, mode = 'rw', id = nil)
      @io = io
      @multiplexer = nil
      @attached = false
      @close_scheduled = false
      @eof_scheduled = false
      @exception = nil

      @mode = mode
      unless mode.index('r').nil?
        @read_buffer = StringBuffer.new
        @pause = false
      end
      unless mode.index('w').nil?
        @write_buffer = StringBuffer.new
        @write_immediately = false
      end

      @id = id || calculate_id
      nil
    end

    def addr
      @io.addr
    end

    def peeraddr
      @io.peeraddr
    end

    def attach(multiplexer)
      fail ArgumentError, 'Socket is already attached' if @attached

      @multiplexer = multiplexer
      initialize_logger multiplexer.logger, multiplexer.logger_context.dup
      add_logger_context 'client', @id

      @multiplexer.wait_read self unless @mode.index('r').nil?
      @multiplexer.wait_write self \
        if can_write_immediately? && !@mode.index('r').nil?

      @attached = true
      nil
    end

    def detach
      fail ArgumentError, 'Socket is not yet attached' unless @attached
      @attached = false
      nil
    end

    def close
      @read_buffer.reset
      if !@mode.index('w').nil?
        @close_scheduled = true
      else
        force_close
      end
      nil
    end

    def force_close
      @multiplexer.remove self
      @io.close unless @io.closed?
      nil
    end

    private

    def _calculate_id
      if @io.respond_to?(:peeraddr)
        begin
          peer = @io.peeraddr(:numeric)
          return "#{peer[2]}:#{peer[1]}"
        rescue NotImplementedError, Errno::ENOTCONN
          return @io.inspect
        end
      end

      @io.inspect
    end
  end
end
