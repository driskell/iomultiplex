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
