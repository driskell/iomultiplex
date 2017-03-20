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
require 'iomultiplex/mixins/ioreactor/openssl'
require_relative '../../ioreactor/helper'

# IOReactor with the OpenSSL mixin for testing
class OpenSSLIOReactor < IOMultiplex::IOReactor
  include IOMultiplex::Mixins::IOReactor::OpenSSL
end

RSpec.describe IOMultiplex::Mixins::IOReactor::OpenSSL do
  include IOMultiplex::IOReactorHelper

  before :example do
    setup_abstract

    expect(@multiplexer).to receive(:wait_read)
    @r = make_reactor 'rw', OpenSSLIOReactor
  end

  describe 'handle_read' do
    it 'waits for write if WaitWritable is thrown and falls through to write' do
      data = make_data(10)
      @r.instance_variable_get(:@write_buffer).push data

      expect(@io).to receive(:read_nonblock) do
        raise IOMultiplex::WaitWritable
      end
      expect(@multiplexer).to receive(:stop_read)
      expect(@multiplexer).to receive(:wait_write)
      @r.handle_read

      # Ensure we keep waiting on write
      expect(@io).to receive(:read_nonblock) do
        raise IOMultiplex::WaitWritable
      end
      @r.handle_write

      expect(@io).to receive(:read_nonblock) do
        # So we don't need to worry about data processing
        raise IOMultiplex::WaitReadable
      end
      expect(@io).to receive(:write_nonblock).and_return data.length
      expect(@multiplexer).to receive(:stop_write)
      expect(@multiplexer).to receive(:wait_read)
      @r.handle_write
    end
  end

  describe 'handle_write' do
    it 'waits for read if WaitReadable is thrown and falls through to read' do
      data = make_data(10)

      expect(@io).to receive(:write_nonblock) do
        raise IOMultiplex::WaitReadable
      end
      @r.write data

      # Ensure we keep waiting on read
      expect(@io).to receive(:write_nonblock) do
        raise IOMultiplex::WaitReadable
      end
      @r.handle_read

      expect(@io).to receive(:write_nonblock).and_return data.length
      expect(@io).to receive(:read_nonblock) do
        raise IOMultiplex::WaitReadable
      end
      @r.handle_read
    end
  end
end
