# encoding: utf-8

# Copyright 2014-2016 Jason Woods.
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

require 'iomultiplex'
require_relative './helper'

RSpec.describe IOMultiplex::IOReactor::TCPSocket do
  include IOMultiplex::IOReactorHelper

  before :example do
    setup_concrete
  end

  after :example do
    teardown_concrete
  end

  describe 'bind' do
    it 'raises if you call it multiple times' do
      l = make_socket
      l.bind '127.0.0.1', reusable_port
      expect do
        l.bind '127.0.0.1', 12_346
      end.to raise_error(IOError)
    end

    it 'binds to the correct host and port' do
      l = make_socket
      l.bind '127.0.0.1', reusable_port
      io = l.instance_variable_get(:@io)
      port, host = ::Socket.unpack_sockaddr_in(io.getsockname)
      expect(port).to eq reusable_port
      expect(host).to eq '127.0.0.1'
    end
  end

  describe 'listen' do
    it 'raises if you call it multiple times' do
      l = make_socket
      expect(l).to_not receive(:connection)
      expect(@multiplexer).to receive(:wait_read)
      l.listen
      expect do
        l.listen
      end.to raise_error(IOError)
    end

    it 'raises if the connection method is not defined' do
      l = make_socket
      expect do
        l.listen
      end.to raise_error(RuntimeError)
    end

    it 'raises if the socket is already connecting to something' do
      l = make_socket
      expect(@multiplexer).to receive(:wait_write)
      l.connect '127.0.0.1', reusable_port
      expect do
        l.listen
      end.to raise_error(IOError)
    end
  end

  describe 'connect' do
    it 'raises if called multiple times' do
      l = make_socket
      expect(@multiplexer).to receive(:wait_write)
      l.connect '127.0.0.1', reusable_port
      expect do
        l.connect '127.0.0.1', reusable_port
      end.to raise_error(IOError)
    end

    it 'raises if the socket is already listening' do
      l = make_socket
      expect(l).to_not receive(:connection)
      expect(@multiplexer).to receive(:wait_read)
      l.listen
      expect do
        l.connect '127.0.0.1', reusable_port
      end.to raise_error(IOError)
    end

    it 'calls exception method with an exception if connection failed' do
      l = make_socket
      expect(@multiplexer).to receive(:wait_write)
      l.connect '127.0.0.1', reusable_port
      expect(@multiplexer).to receive(:remove)
      expect(l).to receive(:exception)
      l.handle_write
    end
  end

  describe 'handle_read' do
    context 'listening and no connections are available' do
      it 'returns silently' do
        l = make_socket
        expect(l).to_not receive(:connection)
        expect(@multiplexer).to receive(:wait_read)
        l.listen
        expect do
          l.handle_read
        end.to_not raise_error
      end
    end

    context 'listening and a connection is available' do
      before :example do
        @l = make_socket
        @connection_called = false
        expect(@l).to receive(:connection) do |io|
          @close_list.push io
          @connection_called = true
        end
        expect(@multiplexer).to receive(:wait_read)
        port = discardable_port
        @l.bind '127.0.0.1', port
        @l.listen

        setup_connector port
      end

      after :example do
        teardown_connector
      end

      it 'calls connection' do
        @l.handle_read
        until @connection_called
          sleep 0.1
          @l.handle_read
        end
      end
    end
  end

  describe 'addr' do
    before :example do
      @l = make_socket
      @l.bind '127.0.0.1', reusable_port
    end

    it 'returns the local address we are bound to with a reverse lookup' do
      expect(@l.addr).to eq ['AF_INET', reusable_port, 'localhost', '127.0.0.1']
    end

    it 'does not perform reverse lookup if given :numeric or false' do
      prediction = ['AF_INET', reusable_port, '127.0.0.1', '127.0.0.1']
      expect(@l.addr(:numeric)).to eq prediction
      expect(@l.addr(false)).to eq prediction
    end

    it 'does perform reverse lookup if given :hostname or true' do
      prediction = ['AF_INET', reusable_port, 'localhost', '127.0.0.1']
      expect(@l.addr(:hostname)).to eq prediction
      expect(@l.addr(true)).to eq prediction
    end
  end

  context 'with a connecting/connected socket' do
    before :example do
      setup_listener
    end

    after :example do
      teardown_listener
    end

    describe 'handle_write' do
      it 'calls connected when the connection is established' do
        c = make_socket
        expect(@multiplexer).to receive(:wait_write)
        c.connect '127.0.0.1', @port
        expect(@multiplexer).to receive(:stop_write)
        expect(@multiplexer).to receive(:wait_read)
        expect(c).to receive(:connected)
        c.handle_write
      end

      it 'does not try to remove write event if connection is immediate' do
        c = make_socket
        # Connection is never immediate on INET so just simulate the state
        expect(@multiplexer).to receive(:wait_write)
        c.connect '127.0.0.1', @port
        c.instance_variable_set :@write_immediately, true

        expect(@multiplexer).to receive(:wait_read)
        expect(c).to receive(:connected)
        c.handle_write
      end

      it 'performs default reactor behavior if socket is connected' do
        io = ::TCPSocket.new '127.0.0.1', @port
        s = make_socket(io)
        s.instance_variable_get(:@write_buffer) << '1234567890'
        expect(io).to receive(:write_nonblock).and_return 10
        s.handle_write
      end

      it 'falls through to a data read immediately after connection' do
        l = make_socket
        io = l.instance_variable_get(:@io)
        expect(@multiplexer).to receive(:wait_write)
        l.connect '127.0.0.1', reusable_port

        # Connect on the write and fall through
        expect(io).to receive(:connect_nonblock) do
          raise Errno::EISCONN
        end
        expect(@multiplexer).to receive(:stop_write)
        expect(io).to receive(:read_nonblock) do
          raise IOMultiplex::WaitReadable
        end
        expect(@multiplexer).to receive(:wait_read)
        l.handle_write
      end
    end

    describe 'handle_read' do
      it 'performs default reactor read behaviour' do
        io = ::TCPSocket.new '127.0.0.1', @port
        s = make_socket(io)
        expect(io).to receive(:read_nonblock).and_return '1234567890'
        expect(s).to receive(:process) do
          expect(s.read(10)).to eq '1234567890'
        end
        s.handle_read
      end
    end

    describe 'peeraddr' do
      before :example do
        io = ::TCPSocket.new '127.0.0.1', @port
        @r = make_socket(io)
      end

      it 'returns the remote address we are connected to with reverse lookup' do
        expect(@r.peeraddr).to eq ['AF_INET', @port, 'localhost', '127.0.0.1']
      end

      it 'does not perform reverse lookup if given :numeric or false' do
        prediction = ['AF_INET', @port, '127.0.0.1', '127.0.0.1']
        expect(@r.peeraddr(:numeric)).to eq prediction
        expect(@r.peeraddr(false)).to eq prediction
      end

      it 'does perform reverse lookup if given :hostname or true' do
        prediction = ['AF_INET', @port, 'localhost', '127.0.0.1']
        expect(@r.peeraddr(:hostname)).to eq prediction
        expect(@r.peeraddr(true)).to eq prediction
      end
    end

    describe 'calculate_id' do
      before :example do
        io = ::TCPSocket.new '127.0.0.1', @port
        @close_list.push io
        loop do
          sleep 0.1
          break if @semaphore.synchronize do
            @finished
          end
        end
      end

      it 'sets the socket ID to the connected endpoint' do
        _, port, = @endpoint.peeraddr
        remote = make_socket(@endpoint)
        expect(remote.instance_variable_get(:@id)).to eq "127.0.0.1:#{port}"
      end
    end
  end
end
