# encoding: utf-8

# Copyright 2014-2016 Jason Woods
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

# TODO: Refactor and finish

require 'iomultiplex/mixins/logger'

module IOMultiplex
  # A pool of multiplexers amongst which incoming connections can be distributed
  class MultiplexerPool
    include Mixins::Logger

    def initialize(options)
      %w(parent num_workers).each do |k|
        raise ArgumentError, "Required option missing: #{k}" \
          unless options[k.to_sym]
      end

      initialize_logger options[:logger], options[:logger_context]

      @id = options[:id] || object_id
      add_logger_context 'multiplexer_pool', @id

      @parent = options[:parent]
      @workers = []
      @pipes = []
      @queues = []
      @threads = []

      options[:num_workers].times do |i|
        @workers[i] = Multiplexer.new \
          logger: logger,
          logger_context: logger_context,
          id: "#{options[:id]}-Worker-#{i}"
        @workers[i].add @pipes[i].reader, false
        @parent.add @pipes[i].writer, false
        @queues[i] = Queue.new

        @threads[i] = Thread.new(@workers[i], &:run)
      end
      nil
    end

    def distribute(client)
      selected = [nil, nil]
      @workers.each_index do |i|
        connections = @workers[i].connections
        # TODO: Make customisable this maxmium
        next if connections >= 1000
        selected = [i, connections] if !selected[0] || selected[1] > connections
      end

      return false unless selected[0]

      @queues[selected[0]] << client
      @workers[selected[0]].callback process, i
      true
    end

    def shutdown
      # Raise shutdown in all client threads and join then
      @workers.each(&shutdown)
      @threads.each(&:join)
      nil
    end

    private

    def process(i)
      loop do
        # Socket for the worker
        length = @queues[i].length
        log_debug 'Receiving new sockets', length: length
        while length != 0
          @workers[i].add @queues[i].pop
          length -= 1
        end
      end
      nil
    end
  end
end
