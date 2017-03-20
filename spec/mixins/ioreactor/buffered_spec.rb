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
require 'iomultiplex/mixins/ioreactor/buffered'
require_relative '../../ioreactor/helper'

# IOReactor with the Buffered mixin for testing
class BufferedIOReactor < IOMultiplex::IOReactor
  include IOMultiplex::Mixins::IOReactor::Buffered
end

RSpec.describe IOMultiplex::Mixins::IOReactor::Buffered do
  include IOMultiplex::IOReactorHelper

  before :example do
    setup_abstract
  end

  describe 'do_read and schedule_read' do
    before :example do
      expect(@multiplexer).to receive(:wait_read)
      @r = make_reactor 'r', BufferedIOReactor
    end

    it 'keeps forcing a read until WaitReadable is thrown' do
      allow(@r).to receive(:process) do
        @r.read 5
      end

      expect(@io).to receive(:read_nonblock).with(read_size).and_return '12345'
      expect(@multiplexer).to receive(:stop_read)
      expect(@multiplexer).to receive(:force_read)
      @r.handle_read

      expect(@io).to receive(:read_nonblock).with(read_size).and_return '67890'
      expect(@multiplexer).to receive(:force_read)
      @r.handle_read

      expect(@io).to receive(:read_nonblock).with(read_size) do
        raise IOMultiplex::WaitReadable
      end
      expect(@multiplexer).to receive(:wait_read)
      @r.handle_read
    end
  end
end
