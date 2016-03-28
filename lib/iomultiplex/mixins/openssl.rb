module IOMultiplex
  module Mixins
    # OpenSSL mixin, shared code amongst the OpenSSL IOReactors
    module OpenSSL
      def handle_read
        if @write_on_read
          handle_write

          # Still need more reads to complete a write?
          return if @write_on_read
        end

        super

        # If we were waiting for a write signal so we could complete a read
        # call, clear it since we now completed it
        if @read_on_write
          @read_on_write = false
          @multiplexer.wait_read self unless write_full?
        end
      rescue IO::WaitWritable
        # TODO: handle_data should really be triggered
        # This captures an OpenSSL read wanting a write
        @multiplexer.stop_read self
        @multiplexer.wait_write self
        @read_on_write = true

        # Don't allow a write to run until we've finished our read
        @write_immediately = false
      end

      def handle_write
        if @read_on_write
          handle_read

          # Still need more writes to complete a read?
          return if @read_on_write
        end

        # Since we didn't hit a WaitWritable we may have more room to write, so
        # allow write immediately flag to be set, or even data to be written
        super

        # If we were waiting for a read signal so we could complete a write
        # call, clear it since we now completed it
        if @write_on_read
          @write_on_read = false
          @write_immediately = true
        end
      rescue IO::WaitReadable
        # Write needs a read
        @multiplexer.stop_write self
        @multiplexer.wait_read self
        @write_on_read = true
      end

      def peer_cert
        @ssl.peer_cert
      end

      def peer_cert_cn
        return nil unless peer_cert
        return @peer_cert_cn unless @peer_cert_cn.nil?
        @peer_cert_cn = peer_cert.subject.to_a.find do |oid, value|
          return value if oid == 'CN'
          nil
        end
      end

      def handshake_completed?
        @handshake_completed
      end

      protected

      def initialize_openssl(ssl_ctx)
        @ssl = OpenSSL::SSL::SSLSocket.new(@io, ssl_ctx)
        @ssl_ctx = ssl_ctx
        @handshake_completed = false
        @read_on_write = false
        nil
      end

      def can_write_immediately?
        false
      end

      def process_handshake
        @ssl.accept_nonblock
        @handshake_completed = true
        add_log_context 'peer_cert_cn', peer_cert_cn

        handshake_completed if respond_to?(:handshake_completed)

        log_debug 'Handshake completed'
      end
    end # ::OpenSSL
  end # ::Mixins
end # ::IOMultiplex
