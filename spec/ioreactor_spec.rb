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
require_relative './ioreactor/helper'

RSpec.describe IOMultiplex::IOReactor do
  include IOMultiplex::IOReactorHelper

  before :example do
    setup
  end

  # Test one of the the test helpers...
  context 'make_data' do
    it 'returns the correct size data' do
      expect(make_data(1024).length).to eq 1024
      expect(make_data(990).length).to eq 990
      expect(make_data(5).length).to eq 5
    end
  end

  context 'initialize' do
    it 'waits for read when attached in read-only mode' do
      expect(@multiplexer).to receive(:wait_read)
      make_reactor 'r'
    end

    it 'waits for nothing when attached in write-only mode' do
      make_reactor 'w'
    end

    it 'waits for read only when attached in read-write mode' do
      expect(@multiplexer).to receive(:wait_read)
      make_reactor 'rw'
    end
  end
end
