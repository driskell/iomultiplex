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

RSpec.describe IOMultiplex::Mixins::IOReactor::Write do
  include IOMultiplex::IOReactorHelper

  before :example do
    setup
  end

  context 'write' do
    before :example do
      make_reactor 'w'
    end

    it 'immediately writes data on the first write' do
      data = make_data(1024)
      expect(@io).to receive(:write_nonblock).with(data).and_return(data.length)
      @r.write data
    end

    it 'waits for write if immediate write raised WaitWritable' do
      data = make_data(1024)
      expect(@io).to receive(:write_nonblock) do
        raise IOMultiplex::WaitWritable
      end
      expect(@multiplexer).to receive(:wait_write)
      @r.write data

      expect(@r.instance_variable_get(:@write_immediately)).to be false
    end

    it 'buffers writes until write is available again' do
      data = make_data(1024)
      expect(@io).to receive(:write_nonblock) do
        raise IOMultiplex::WaitWritable
      end
      expect(@multiplexer).to receive(:wait_write)
      @r.write data
      @r.write data

      expect(@io).to receive(:write_nonblock).and_return(data.length * 2)
      expect(@multiplexer).to receive(:stop_write)
      @r.handle_write

      expect(@r.instance_variable_get(:@write_immediately)).to be true
    end
  end
end
