require 'openssl'

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

        begin
          super
        rescue ::OpenSSL::SSL::SSLError => e
          read_exception e
        end

        # If we were waiting for a write signal so we could complete a read
        # call, clear it since we now completed it
        reset_read_on_write if @read_on_write
      rescue IO::WaitWritable
        # TODO: handle_data should really be triggered
        # This captures an OpenSSL read wanting a write
        @multiplexer.stop_read self
        @multiplexer.wait_write self
        @read_on_write = true

        log_debug 'OpenSSL wants read on write'
      end

      def handle_write
        if @read_on_write
          handle_read

          # Still need more writes to complete a read?
          return if @read_on_write
        end

        # Since we didn't hit a WaitWritable we may have more room to write, so
        # allow write immediately flag to be set, or even data to be written
        begin
          super
        rescue ::OpenSSL::SSL::SSLError => e
          write_exception e
        end

        # If we were waiting for a read signal so we could complete a write
        # call, clear it since we now completed it
        reset_write_on_read if @write_on_read
      rescue IO::WaitReadable
        # Write needs a read
        @multiplexer.stop_write self
        @multiplexer.wait_read self
        @write_on_read = true

        log_debug 'OpenSSL wants write on read'
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

      def initialize_ssl(ssl_ctx)
        @ssl = ::OpenSSL::SSL::SSLSocket.new(@io, ssl_ctx)
        @ssl_ctx = ssl_ctx
        @handshake_completed = false
        @read_on_write = false
        nil
      end

      def ssl_read_nonblock(n)
        read = @ssl.read_nonblock n
      ensure
        log_debug 'SSL read_nonblock',
                  count: n, read: read.nil? ? nil : read.length
      end

      def ssl_write_nonblock(data)
        written = @ssl.write_nonblock data
      ensure
        log_debug 'SSL write_nonblock',
                  count: data.length, written: written
      end

      def reset_read_on_write
        @read_on_write = false
        @multiplexer.wait_read self unless write_full?
      end

      def reset_write_on_read
        @write_on_read = false
        @write_immediately = true
      end

      def process_handshake
        @ssl.accept_nonblock
        @handshake_completed = true
        add_logger_context 'peer_cert_cn', peer_cert_cn

        handshake_completed if respond_to?(:handshake_completed)

        log_debug 'Handshake completed'
      end
    end # ::OpenSSL
  end # ::Mixins
end # ::IOMultiplex
