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
    # Manages a TCPSocket object
    class TCPSocket < IOReactor
      def initialize(id = nil, io = nil)
        super io || ::Socket.new(::Socket::PF_INET, ::Socket::SOCK_STREAM),
              'rw', id

        @connected = !io.nil?
        @connect_to = @connected
        @bound = @connected
        @listening = false
      end

      # Don't wait for anything when we attach
      def multiplexer=(multiplexer)
        raise 'Already attached' if @multiplexer
        return super multiplexer if @connected
        @multiplexer = multiplexer
      end

      # Override handle_read to handle listening
      def handle_read
        return handle_accept if @listening
        super
      end

      # Override handle_write to handle connecting
      def handle_write
        return handle_connect unless @connected
        super
      end

      def bind(host, port)
        raise IOError, 'Already bound' if @bound

        @bound = true
        @io.bind ::Socket.sockaddr_in(port, host)

        nil
      end

      def listen(backlog = 50)
        raise IOError, 'Already listening' if @listening
        raise IOError, 'Already connected' if @connect_to
        raise 'Must define connection method' unless respond_to?(:connection)

        @listening = true
        @bound = true
        @io.listen backlog
        @multiplexer.wait_read self

        nil
      end

      def connect(host, port)
        raise IOError, 'Already listening' if @listening
        raise IOError, 'Already connected' if @connect_to

        @connect_to = Socket.sockaddr_in(port, host)
        @bound = true
        handle_connect
      end

      def addr(reverse_lookup = true)
        sockaddr_in_to_addr @io.getsockname, reverse_lookup
      end

      def peeraddr(reverse_lookup = true)
        sockaddr_in_to_addr @io.getpeername, reverse_lookup
      end

      protected

      def handle_accept
        begin
          socket = @io.accept_nonblock
        rescue IO::WaitReadable
          return
        end

        connection socket[0]
      end

      def handle_connect
        begin
          @io.connect_nonblock(@connect_to)
        rescue Errno::EISCONN
          nil
        rescue IO::WaitWritable
          @multiplexer.wait_write self
          @write_immediately = false
          return
        rescue IOError, Errno::ECONNREFUSED => e
          return write_exception(e)
        end

        @connected = true
        @multiplexer.stop_write self unless @write_immediately
        @multiplexer.wait_read self
        @write_immediately = true

        nil
      end

      def sockaddr_in_to_addr(sockaddr_in, reverse_lookup)
        port, host = ::Socket.unpack_sockaddr_in(sockaddr_in)
        ::Socket.getaddrinfo(
          host, port,
          :INET, :STREAM, 0,
          0, reverse_lookup
        )[0].slice! 0, 4
      end

      def calculate_id
        peer = peeraddr(:numeric)
        # IPv4 format
        return "#{peer[2]}:#{peer[1]}" # if peer[2].index(':').nil?
        # IPv6 format
        # return "[#{peer[2]}]:#{peer[1]}"
      rescue NotImplementedError, Errno::ENOTCONN
        return @io.inspect
      end
    end # ::TCPSocket
  end # ::IOReactor
end # ::IOMultiplex
