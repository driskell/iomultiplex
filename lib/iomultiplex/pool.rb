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

    attr_reader :id

    def initialize(options)
      %w(num_workers).each do |k|
        raise ArgumentError, "Required option missing: #{k}" \
          unless options[k.to_sym]
      end

      initialize_logger options[:logger], options[:logger_context]

      @id = options[:id] || object_id
      add_logger_context 'multiplexer_pool', @id

      @num_workers = options[:num_workers]
      @queued_clients = []

      reset_state
    end

    def start
      raise 'Already started' unless @workers.empty?

      @num_workers.times do |i|
        @workers[i] = Multiplexer.new \
          logger: logger,
          logger_context: logger_context,
          id: "Worker-#{i}"

        @queues[i] = Queue.new

        @threads[i] = Thread.new(@workers[i], &:run)
      end

      distribute_queued_clients
      nil
    end

    def distribute(client)
      return queue_client(client) if @workers.empty?

      s = nil
      c = 0
      @workers.each_index do |i|
        connections = @workers[i].connections
        # TODO: Make customisable this maxmium
        next unless connections < 1000 && (s.nil? || c > connections)
        s = i
        c = connections
      end

      return false if s.nil?
      worker = @workers[s]

      log_debug 'Distributing new client',
                :client => client.id, :worker => worker.id
      @queues[s] << client
      worker.callback do
        process s
      end
      true
    end

    def shutdown
      raise 'Not started' if @workers.empty?

      # Raise shutdown in all client threads and join then
      @workers.each(&:shutdown)
      @threads.each(&:join)

      reset_state
      nil
    end

    private

    def reset_state
      @workers = []
      @queues = []
      @threads = []
    end

    def queue_client(client)
      @queued_clients << client
      nil
    end

    def distribute_queued_clients
      distribute @queued_clients.pop until @queued_clients.empty?
      nil
    end

    def process(i)
      # Sockets for the worker
      log_debug 'Receiving new sockets', length: @queues[i].length
      @workers[i].add @queues[i].pop until @queues[i].empty?
      nil
    end
  end
end
