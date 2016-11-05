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
require_relative './helper'

RSpec.describe IOMultiplex::Mixins::IOReactor::Read do
  include IOMultiplex::IOReactorHelper

  before :example do
    setup
  end

  context 'read' do
    before :example do
      expect(@multiplexer).to receive(:wait_read)
      make_reactor 'r'
    end

    it 'returns the data from the buffer if it has some' do
      @r.instance_variable_get(:@read_buffer) << '1234567890'
      expect(@r.read(5)).to eq '12345'
      expect(@r.read(5)).to eq '67890'
    end

    it 'raises NotEnoughData if buffer is not big enough' do
      expect do
        @r.read 10
      end.to raise_error(IOMultiplex::NotEnoughData)
    end
  end

  context 'discard' do
    before :example do
      expect(@multiplexer).to receive(:wait_read)
      make_reactor 'r'
    end

    it 'empties the read buffer' do
      @r.instance_variable_get(:@read_buffer) << '1234567890'
      expect(@r.read(5)).to eq '12345'
      @r.discard
      expect do
        @r.read 5
      end.to raise_error(IOMultiplex::NotEnoughData)
    end
  end

  context 'handle_read and handle_data' do
    before :example do
      expect(@multiplexer).to receive(:wait_read)
      make_reactor 'r'
    end

    it 'reads from the IO object' do
      expect(@io).to receive(:read_nonblock).with(read_size)
      @r.handle_read
    end

    it 'handles WaitReadable and EINTR/EAGAIN exceptions during read' do
      expect(@io).to receive(:read_nonblock) { raise IOMultiplex::WaitReadable }
      @r.handle_read

      expect(@io).to receive(:read_nonblock) { raise Errno::EINTR }
      @r.handle_read

      expect(@io).to receive(:read_nonblock) { raise Errno::EAGAIN }
      @r.handle_read
    end

    it 'gracefully raises an exception and closes if an IOError occurs' do
      expect(@io).to receive(:read_nonblock).with(
        IOMultiplex::Mixins::IOReactor::Read::READ_SIZE
      ) { raise IOError }
      expect(@io).to receive(:close)
      expect(@r).to receive(:exception).with(IOError)
      expect(@multiplexer).to receive(:stop_read)
      expect(@multiplexer).to receive(:remove)
      @r.handle_read
    end

    it 'gracefully raises connection reset errors' do
      expect(@io).to receive(:read_nonblock).with(
        IOMultiplex::Mixins::IOReactor::Read::READ_SIZE
      ) { raise Errno::ECONNRESET }
      expect(@io).to receive(:close)
      expect(@r).to receive(:exception).with(Errno::ECONNRESET)
      expect(@multiplexer).to receive(:stop_read)
      expect(@multiplexer).to receive(:remove)
      @r.handle_read
    end

    it 'defers read if we do not read all data' do
      expect(@io).to receive(:read_nonblock).and_return make_data(read_size)
      expect(@r).to receive(:process) { @r.read(read_size / 2) }
      expect(@multiplexer).to receive(:defer)
      @r.handle_read
    end

    it 'stops reading if the buffer becomes full and defers' do
      expect(@io).to receive(:read_nonblock).and_return \
        make_data(read_buffer_max)
      expect(@r).to receive(:process)
      expect(@multiplexer).to receive(:stop_read)
      expect(@multiplexer).to receive(:defer)
      @r.handle_read
    end

    it 'allows the buffer to overfill if a read needs more than buffer size' do
      expect(@io).to receive(:read_nonblock).and_return make_data(read_size)
      expect(@r).to receive(:process) { @r.read(read_size * 2) }
      expect(@multiplexer).to receive(:defer)
      @r.handle_read

      expect(@io).to receive(:read_nonblock).and_return make_data(read_size)
      expect(@r).to receive(:process) { @r.read(read_size * 2) }
      @r.handle_read
    end

    it 'starts reading again if the buffer was full and we cleared it' do
      expect(@io).to receive(:read_nonblock).and_return make_data(read_size)
      expect(@r).to receive(:process)
      expect(@multiplexer).to receive(:stop_read)
      expect(@multiplexer).to receive(:defer)
      @r.handle_read

      expect(@r).to receive(:process) { @r.read(read_size / 2) }
      expect(@multiplexer).to receive(:wait_read)
      expect(@multiplexer).to receive(:defer)
      @r.handle_data
    end
  end

  context 'eof' do
    before :example do
      expect(@multiplexer).to receive(:wait_read)
      make_reactor 'r'
    end

    it 'is triggered and socket removed if no data in the buffer' do
      expect(@io).to receive(:read_nonblock) { raise EOFError }
      expect(@r).to receive(:eof)
      expect(@multiplexer).to receive(:stop_read)
      expect(@multiplexer).to receive(:remove)
      @r.handle_read
    end

    it 'is triggered when we finished reading all data' do
      expect(@io).to receive(:read_nonblock).and_return make_data(10)
      expect(@r).to receive(:process) { @r.read(5) }
      expect(@multiplexer).to receive(:defer)
      @r.handle_read

      expect(@io).to receive(:read_nonblock) { raise EOFError }
      expect(@r).to receive(:process) { @r.read(5) }
      expect(@r).to receive(:eof)
      expect(@multiplexer).to receive(:stop_read)
      expect(@multiplexer).to receive(:remove)
      @r.handle_read
    end

    it 'is triggered when we expect more data than available' do
      expect(@io).to receive(:read_nonblock).and_return make_data(10)
      expect(@r).to receive(:process) { @r.read(5) }
      expect(@multiplexer).to receive(:defer)
      @r.handle_read

      expect(@io).to receive(:read_nonblock) { raise EOFError }
      expect(@r).to receive(:process) { @r.read(50) }
      expect(@r).to receive(:eof)
      expect(@multiplexer).to receive(:stop_read)
      expect(@multiplexer).to receive(:remove)
      @r.handle_read
    end
  end

  context 'eof with duplex' do
    before :example do
      expect(@multiplexer).to receive(:wait_read)
      make_reactor 'rw'
    end

    it 'prevents further reading' do
      expect(@io).to receive(:read_nonblock).with(
        IOMultiplex::Mixins::IOReactor::Read::READ_SIZE
      ) { raise EOFError }
      expect(@multiplexer).to receive(:stop_read)
      @r.handle_read
    end
  end

  context 'pause and resume' do
    before do
      expect(@multiplexer).to receive(:wait_read)
      make_reactor 'r'
    end

    it 'reschedules accordingly' do
      expect(@io).to receive(:read_nonblock).and_return make_data(10)
      expect(@r).to receive(:process) { @r.pause }
      expect(@multiplexer).to receive(:stop_read)
      @r.handle_read

      expect(@multiplexer).to receive(:wait_read)
      expect(@multiplexer).to receive(:defer)
      @r.resume

      expect(@io).to receive(:read_nonblock).and_return ''
      expect(@r).to receive(:process) { @r.read(10) }
      @r.handle_read
    end
  end
end
