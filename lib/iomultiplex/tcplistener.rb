require 'iomultiplex/ioreactor'

module IOMultiplex
  # A TCP listener
  class TCPListener < IOReactor
    def initialize(address, port, pool = nil, &block)
      raise RuntimeError, 'connection_accepted not implemented', nil \
        unless block_given? || respond_to?(:connection_accepted)
      super TCPServer.new(address, port), 'r'
      @io.listen 1024
      @pool = pool
      @block = block
    end

    protected

    # Replace the IOReactor read_action - we need to call accept, not read
    # Accept up to 10 connections at a time so we don't block the IO thread
    # for too long
    def read_action
      10.times do
        accept_one
      end
    end

    def accept_one
      socket = @io.accept_nonblock
      client = @block ? @block.call(socket) : connection_accepted(socket)
      unless client
        socket.close
        return
      end
      if @pool
        @pool.distribute client
      else
        @multiplexer.add client
      end
    end
  end
end
