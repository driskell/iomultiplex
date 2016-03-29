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

require 'iomultiplex/mixins/ioreactor/read'
require 'iomultiplex/mixins/ioreactor/write'
require 'iomultiplex/stringbuffer'

module IOMultiplex
  # IOReactor - reactor style wrapper around IO objects
  class IOReactor
    attr_reader :id
    attr_reader :io
    attr_reader :mode
    attr_reader :peer

    include Mixins::Logger
    include Mixins::IOReactor::Read
    include Mixins::IOReactor::Write

    def initialize(io, mode = 'rw', id = nil)
      @io = io
      @multiplexer = nil
      @attached = false
      @close_scheduled = false
      @eof_scheduled = false
      @exception = nil

      @r = mode.index('r').nil? ? false : true
      @w = mode.index('w').nil? ? false : true

      if @r
        @read_buffer = StringBuffer.new
        @pause = false
      end
      if @w
        @write_buffer = StringBuffer.new
        @write_immediately = true
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
      raise ArgumentError, 'Socket is already attached' if @attached

      @multiplexer = multiplexer
      initialize_logger multiplexer.logger, multiplexer.logger_context.dup
      add_logger_context 'client', @id

      @multiplexer.wait_read self if @r

      @attached = true
      nil
    end

    def detach
      raise ArgumentError, 'Socket is not yet attached' unless @attached
      @attached = false
      nil
    end

    def close
      @read_buffer.reset
      if !@w
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

    protected

    def calculate_id
      if @io.respond_to?(:peeraddr)
        begin
          peer = @io.peeraddr(:numeric)
          # IPv4 format
          return "#{peer[2]}:#{peer[1]}" if peer[2].index(':').nil?
          # IPv6 format
          return "[#{peer[2]}]:#{peer[1]}"
        rescue NotImplementedError, Errno::ENOTCONN
          return @io.inspect
        end
      end

      @io.inspect
    end
  end # ::IOReactor
end # ::IOMultiplex
