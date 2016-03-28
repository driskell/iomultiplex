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

require 'cabin'
require 'iomultiplex'

RSpec.describe IOMultiplex::IOReactorRead do
  context 'initialize' do
    before :example do
      @io = double
      @logger = instance_spy(Cabin::Channel)
      @multiplexer = instance_double(IOMultiplex::Multiplexer)
    end

    it 'waits for read when attached in read-only mode' do
      expect(@multiplexer).to receive(:wait_read)
      IOMultiplex::IOReactor.new(@io, 'r').attach @multiplexer, @logger
    end

    it 'waits for write when attached in write-only mode' do
      expect(@multiplexer).to receive(:wait_write)
      IOMultiplex::IOReactor.new(@io, 'w').attach @multiplexer, @logger
    end

    it 'waits for read and write when attached in read-write mode' do
      expect(@multiplexer).to receive(:wait_read)
      expect(@multiplexer).to receive(:wait_write)
      IOMultiplex::IOReactor.new(@io, 'rw').attach @multiplexer, @logger
    end
  end

  def setup(attach = true)
    @io = spy

    @closed = false
    allow(@io).to receive(:closed?) do
      @closed
    end

    @logger = instance_spy(Cabin::Channel)
    @multiplexer = instance_double(IOMultiplex::Multiplexer)
    @r = IOMultiplex::IOReactor.new(@io, 'r')

    return unless attach
    expect(@multiplexer).to receive(:wait_read)
    @r.attach @multiplexer, @logger
  end

  context 'handle_read' do

  end

  context 'handle_data' do
    
  end

  context 'read' do
    before :example do
      setup
    end

    context '(attached)' do
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

      it 'raises IOError if the socket is closed' do
        @r.instance_variable_get(:@read_buffer) << '1234567890'
        @closed = true
        expect do
          @r.read 8
        end.to raise_error(IOError)
      end
    end

    context '(unattached)' do
      before :example do
        setup false
      end

      it 'raises RuntimeError' do
        @r.instance_variable_get(:@read_buffer) << '1234567890'
        expect do
          @r.read 10
        end.to raise_error(RuntimeError)
      end
    end
  end

  context 'discard' do
    before :example do
      setup
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

  context 'reschedule' do

  end
end
