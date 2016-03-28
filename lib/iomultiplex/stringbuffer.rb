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

module IOMultiplex
  # StringBuffer allows us to store the returned allocations from sysread calls
  # as an array of the actual strings, preventing the need for re-allocations
  # to expand a string
  # The allocations only happen at the point that enough data is received to
  # meet a request and at that time only a single allocation is performed
  class StringBuffer
    attr_accessor :length

    def initialize
      reset
    end

    def reset
      @buffer = []
      @length = 0
      nil
    end

    def push(data)
      data = data.to_s
      @buffer.push data
      @length += data.length
    end
    alias << push

    def read(n)
      process n, false
    end

    def peek(n)
      return '' if length == 0 # rubocop:disable Style/ZeroLengthPredicate
      s = ''
      # Coalesce small writes
      i = 0
      while n > 0 && @buffer[i]
        if @buffer[i].length > n
          s << @buffer[i][0, n]
          break
        else
          s << @buffer[i]
          n -= @buffer[i].length
        end
        i += 1
      end
      s
    end

    def shift(n)
      process n, true
    end

    def empty?
      length == 0 # rubocop:disable Style/ZeroLengthPredicate
    end

    private

    def process(n, discard = false)
      data = ''
      n = n.to_i
      while n > 0 && length > 0 # rubocop:disable Style/ZeroLengthPredicate
        s = @buffer[0].length > n ? @buffer[0].slice!(0, n) : @buffer.shift
        n -= s.length
        @length -= s.length
        data << s unless discard
      end
      data
    end
  end
end
