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
    @sockets = []
  end

  def make_socket(io = nil)
    r = IOMultiplex::IOReactor::TCPSocket.new nil, io
    r.set_logger @logger, {}
    r.multiplexer = @multiplexer
    @sockets.push r
    r
  end

  before :example do
    setup
  end

  after :example do
    @sockets.each do |socket|
      socket.instance_variable_get(:@io).close
    end
  end

  context 'bind' do
    it 'only allows bind once' do
      l = make_socket
      l.bind '127.0.0.1', 12_345
      expect do
        l.bind '127.0.0.1', 12_346
      end.to raise_error(IOError)
    end

    it 'binds to the correct host and port' do
      l = make_socket
      l.bind '127.0.0.1', 12_345
      io = l.instance_variable_get(:@io)
      port, host = ::Socket.unpack_sockaddr_in(io.getsockname)
      expect(port).to eq 12_345
      expect(host).to eq '127.0.0.1'
    end
  end

  context 'addr' do
    it 'returns the local address we are bound to with a reverse lookup' do
      l = make_socket
      l.bind '127.0.0.1', 65_432
      expect(l.addr).to eq ['AF_INET', 65_432, 'localhost', '127.0.0.1']
    end

    it 'does not perform reverse lookup if given :numeric or false' do
      l = make_socket
      l.bind '127.0.0.1', 65_432
      prediction = ['AF_INET', 65_432, '127.0.0.1', '127.0.0.1']
      expect(l.addr(:numeric)).to eq prediction
      expect(l.addr(false)).to eq prediction
    end

    it 'does perform reverse lookup if given :hostname or true' do
      l = make_socket
      l.bind '127.0.0.1', 65_432
      prediction = ['AF_INET', 65_432, 'localhost', '127.0.0.1']
      expect(l.addr(:hostname)).to eq prediction
      expect(l.addr(true)).to eq prediction
    end
  end

  context 'bind, listen and connect' do
    it 'binds, listens, and receives connections' do
      l = make_socket
      l.bind '127.0.0.1', 12_345
      connection_called = false
      expect(l).to receive(:connection) do
        connection_called = true
      end
      expect(@multiplexer).to receive(:wait_read).with(l)
      l.listen

      c = make_socket
      expect(@multiplexer).to receive(:wait_write).with(c)
      c.connect '127.0.0.1', 12_345

      expect(@multiplexer).to receive(:stop_write).with(c)
      expect(@multiplexer).to receive(:wait_read).with(c)
      l.handle_read
      c.handle_write
      until connection_called
        sleep 0.5
        l.handle_read
        c.handle_write
      end
    end
  end
end
