module IOMultiplex
  # Test helpers for IOReactor
  module IOReactorHelper
    def setup_abstract
      @io = double
      @closed = false
      @logger = spy
      allow(@io).to receive(:closed?) { @closed }
      allow(@io).to receive(:close) do
        raise IOError if @closed
        @closed = true
      end
      @multiplexer = instance_double(IOMultiplex::Multiplexer)
    end

    def setup_concrete
      @logger = spy
      @multiplexer = instance_double(IOMultiplex::Multiplexer)
      @close_list = []
    end

    def setup_listener
      @port = discardable_port
      l = TCPServer.new '127.0.0.1', @port
      @semaphore = Mutex.new
      @finished = false
      @endpoint = nil
      @listener = Thread.new { run_listener l }
    end

    def setup_connector(port)
      @connector = Thread.new do
        @close_list.push TCPSocket.new('127.0.0.1', port)
      end
    end

    def teardown_concrete
      @close_list.reverse_each(&:close)
    end

    def teardown_listener
      @semaphore.synchronize do
        @finished = true
      end
      @listener.join
    end

    def teardown_connector
      @connector.join
    end

    def make_reactor(mode, cls = IOMultiplex::IOReactor)
      r = cls.new(@io, mode)
      r.set_logger @logger, {}
      r.multiplexer = @multiplexer
      r
    end

    def make_socket(io = nil, cls = IOMultiplex::IOReactor::TCPSocket)
      r = cls.new nil, io
      r.set_logger @logger, {}
      expect(@multiplexer).to receive(:wait_read) unless io.nil?
      r.multiplexer = @multiplexer
      @close_list.push r.instance_variable_get(:@io)
      r
    end

    def run_listener(l)
      loop do
        begin
          io = l.accept_nonblock
          @close_list.push io
          @semaphore.synchronize do
            @finished = true
            @endpoint = io
          end
          break
        rescue IO::WaitReadable
          break if @semaphore.synchronize do
            @finished
          end
          IO.select [l], nil, nil, 0.1
        end
      end
    end

    def make_data(size)
      '1234567890' * (size / 10) + 'X' * (size % 10)
    end

    def read_size
      IOMultiplex::Mixins::IOReactor::Read::READ_SIZE
    end

    def read_buffer_max
      IOMultiplex::Mixins::IOReactor::Read::READ_BUFFER_MAX
    end
  end
end
