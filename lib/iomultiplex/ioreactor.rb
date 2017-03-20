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
    include Mixins::Logger
    include Mixins::IOReactor::Read
    include Mixins::IOReactor::Write

    attr_reader :id
    attr_reader :io
    attr_reader :mode
    attr_reader :peer

    def initialize(io, mode = 'rw', id = nil)
      @io = io
      @multiplexer = nil
      @close_scheduled = false
      @closed = false
      @eof_scheduled = false
      @exception = nil
      @flush_in_progress = false
      @was_paused = false

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

      @read_active = false

      @id = id || calculate_id
      nil
    end

    attr_reader :multiplexer
    def multiplexer=(multiplexer)
      raise 'Already attached' if @multiplexer
      @multiplexer = multiplexer

      @multiplexer.wait_read self if @r
      @read_active = true if @r
    end

    def set_logger(logger, logger_context)
      initialize_logger logger, logger_context
      add_logger_context 'client', @id
      nil
    end

    def close
      @read_buffer.reset
      if @w
        @close_scheduled = true
      else
        force_close
      end
      nil
    end

    def force_close
      return if @closed
      @multiplexer.remove self
      @io.close
      @closed = true
      nil
    end

    protected

    def calculate_id
      @io.inspect
    end
  end # ::IOReactor
end # ::IOMultiplex
