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

require 'iomultiplex'

RSpec.describe IOMultiplex::IOReactor::TCPSocket do
  before :example do
    setup
  end

  def setup
    @logger = spy
    @multiplexer = instance_double(IOMultiplex::Multiplexer)
    @close_list = []
  end

  def make_socket(io = nil)
    r = IOMultiplex::IOReactor::TCPSocket.new nil, io
    r.set_logger @logger, {}
    expect(@multiplexer).to receive(:wait_read) unless io.nil?
    r.multiplexer = @multiplexer
    @close_list.push r.instance_variable_get(:@io)
    r
  end

  before :example do
    setup
  end

  after :example do
    @close_list.reverse_each(&:close)
  end

  context 'bind' do
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

  context 'listen' do
    it 'raises if you call it multiple times' do
      l = make_socket
      allow(l).to receive(:connection)
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

    it 'returns silently if no connections are available' do
      l = make_socket
      allow(l).to receive(:connection)
      expect(@multiplexer).to receive(:wait_read)
      l.listen
      expect do
        l.handle_read
      end.to_not raise_error(IO::WaitReadable)
    end
  end

  context 'connect' do
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
      allow(l).to receive(:connection)
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

  # For testing bind, listen and connect
  # Also for testing peeraddr on the connected socket
  def make_remote_socket
    local_port = discardable_port

    l = make_socket
    l.bind '127.0.0.1', local_port
    connection_called = false
    remote = nil
    expect(l).to receive(:connection) do |io|
      @close_list.push io
      remote = io
      connection_called = true
    end
    expect(@multiplexer).to receive(:wait_read).with(l)
    l.listen

    c = make_socket
    expect(@multiplexer).to receive(:wait_write).with(c)
    c.connect '127.0.0.1', local_port

    expect(@multiplexer).to receive(:stop_write).with(c)
    expect(@multiplexer).to receive(:wait_read).with(c)
    l.handle_read
    c.handle_write
    until connection_called
      sleep 0.5
      l.handle_read
      c.handle_write
    end

    expect(c.instance_variable_get(:@connected)).to be true

    [c, local_port, remote]
  end

  context 'bind, listen and connect' do
    it 'binds, listens, and receives a connection' do
      make_remote_socket
    end
  end

  context 'addr' do
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

  context 'peeraddr' do
    before :example do
      @r, @port, = make_remote_socket
    end

    it 'returns the remote address we are connected to with a reverse lookup' do
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

  context 'calculate_id' do
    it 'sets the socket ID to the connected endpoint' do
      r, _, io = make_remote_socket
      _, port, = r.addr(false)
      remote = make_socket(io)
      expect(remote.instance_variable_get(:@id)).to eq "127.0.0.1:#{port}"
    end
  end
end
