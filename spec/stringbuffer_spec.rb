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

require 'iomultiplex/stringbuffer'

RSpec.describe IOMultiplex::StringBuffer do
  before :example do
    @buffer = IOMultiplex::StringBuffer.new
  end

  it 'stores data and allows it to be read' do
    @buffer.push 'Hello'
    @buffer << 'World'

    expect(@buffer.read(10)).to eq 'HelloWorld'
  end

  it 'stores data and allows it to be read (underflow)' do
    @buffer.push 'Hello'
    @buffer << 'World'

    expect(@buffer.read(15)).to eq 'HelloWorld'
    expect(@buffer.read(15)).to eq ''
  end

  it 'stores data and allows it to be read (boundary)' do
    @buffer.push 'Hello'
    @buffer << 'World'

    expect(@buffer.read(5)).to eq 'Hello'
    expect(@buffer.read(5)).to eq 'World'
  end

  it 'stores data and allows it to be read (within elements)' do
    @buffer.push 'Hello'
    @buffer << 'World'

    expect(@buffer.read(3)).to eq 'Hel'
    expect(@buffer.read(4)).to eq 'loWo'
    expect(@buffer.read(3)).to eq 'rld'
  end

  it 'allows data to be peeked without consuming it' do
    @buffer.push 'Hello'
    @buffer << 'World'

    # Underflow
    expect(@buffer.peek(15)).to eq 'HelloWorld'
    # At boundary
    expect(@buffer.peek(5)).to eq 'Hello'
    expect(@buffer.peek(10)).to eq 'HelloWorld'
    # Within element
    expect(@buffer.peek(3)).to eq 'Hel'
    expect(@buffer.peek(8)).to eq 'HelloWor'

    expect(@buffer.read(15)).to eq 'HelloWorld'
    expect(@buffer.read(15)).to eq ''
  end

  it 'returns the correct length before and after reads' do
    expect(@buffer.length).to eq 0

    @buffer.push 'Hello'
    expect(@buffer.length).to eq 5
    @buffer << 'World'
    expect(@buffer.length).to eq 10

    @buffer.read(3)
    expect(@buffer.length).to eq 7
    @buffer.read(2)
    expect(@buffer.length).to eq 5
    @buffer.read(20)
    expect(@buffer.length).to eq 0
  end

  it 'returns the correct length before and after peeks' do
    expect(@buffer.length).to eq 0

    @buffer.push 'Hello'
    expect(@buffer.length).to eq 5
    @buffer << 'World'
    expect(@buffer.length).to eq 10

    @buffer.peek(3)
    expect(@buffer.length).to eq 10
    @buffer.peek(10)
    expect(@buffer.length).to eq 10
  end

  it 'allows data to be cleared using shift' do
    @buffer.push 'Hello'
    @buffer << 'World'

    @buffer.shift(5)
    expect(@buffer.read(15)).to eq 'World'
  end

  it 'wipes the buffer when reset is called' do
    @buffer.push 'Hello'
    @buffer << 'World'

    @buffer.reset
    expect(@buffer.read(10)).to eq ''
  end
end
