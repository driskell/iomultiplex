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
  # A TCP listener
  class TCPListener < IOReactor
    def initialize(address, port, id = nil, pool = nil, &block)
      raise RuntimeError, 'connection_accepted not implemented', nil \
        unless block_given? || respond_to?(:connection_accepted)
      super TCPServer.new(address, port), 'r', id
      @io.listen 1024
      @pool = pool
      @block = block
    end

    protected

    # Replace the IOReactor read_action - we need to call accept, not read
    # Accept up to 10 connections at a time so we don't block the IO thread
    # for too long
    def read_action
      10.times do
        accept_one
      end
    end

    def accept_one
      socket = @io.accept_nonblock
      client = @block ? @block.call(socket) : connection_accepted(socket)
      unless client
        socket.close
        return
      end
      if @pool
        @pool.distribute client
      else
        @multiplexer.add client
      end
    end
  end
end
