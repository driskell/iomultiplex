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

        super

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

        super

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
      rescue IO::WaitReadable
        # OpenSSL wraps these, keep it flowing throw
        raise
      rescue ::OpenSSL::SSL::SSLError => e
        # Throw back OpenSSL errors as IOErrors
        raise IOError, "#{e.class.name}: #{e}"
      ensure
        log_debug 'SSL read_nonblock',
                  count: n, read: read.nil? ? nil : read.length
      end

      def ssl_write_nonblock(data)
        written = @ssl.write_nonblock data
      rescue IO::WaitWritable
        # OpenSSL wraps these, keep it flowing throw
        raise
      rescue ::OpenSSL::SSL::SSLError => e
        # Throw back OpenSSL errors as IOErrors
        raise IOError, "#{e.class.name}: #{e}"
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
      rescue IO::WaitReadable, IO::WaitWritable
        # OpenSSL wraps these, keep it flowing throw
        raise
      rescue ::OpenSSL::SSL::SSLError => e
        # Throw back OpenSSL errors as IOErrors
        raise IOError, "#{e.class.name}: #{e}"
      end
    end # ::OpenSSL
  end # ::Mixins
end # ::IOMultiplex
