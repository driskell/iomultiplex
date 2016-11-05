module IOMultiplex
  # Test helpers for IOReactor
  module IOReactorHelper
    def setup
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

    def make_reactor(mode)
      r = IOMultiplex::IOReactor.new(@io, mode)
      r.set_logger @logger, {}
      r.multiplexer = @multiplexer
      r
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
