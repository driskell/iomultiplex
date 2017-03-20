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
require 'iomultiplex/mixins/ioreactor/buffered'

module IOMultiplex
  module Mixins
    module IOReactor
      # OpenSSL mixin, shared code amongst the OpenSSL IOReactors
      module OpenSSL
        include Buffered

        def handle_read
          if @write_on_read
            handle_write

            # Still need more reads to complete a write?
            return if @write_on_read || !@read_active
          end

          super

          # If we were waiting for a write signal so we could complete a read
          # call, clear it since we now completed it
          stop_read_on_write
        rescue IO::WaitWritable
          # Read needs a write
          start_read_on_write
        end

        def handle_write
          if @read_on_write
            handle_read

            # Don't stop write_on_read if we still need more writes to complete
            # a read or there's nothing to write if we fall through
            return if @read_on_write || @write_buffer.empty?
          end

          super

          # If we were waiting for a read signal so we could complete a write
          # call, clear it since we now completed it
          stop_write_on_read
        rescue IO::WaitReadable
          # Write needs a read
          start_write_on_read
        end

        def peercert
          @ssl.peer_cert
        end

        def peercertcn
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
          @write_on_read = false
          nil
        end

        def ssl_read_nonblock(n)
          read = @ssl.read_nonblock n
        rescue IO::WaitReadable
          # OpenSSL wraps these in SSLError so we have to catch, let it bubble
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
          # OpenSSL wraps these in SSLError so we have to catch, let it bubble
          raise
        rescue ::OpenSSL::SSL::SSLError => e
          # Throw back OpenSSL errors as IOErrors
          raise IOError, "#{e.class.name}: #{e}"
        ensure
          log_debug 'SSL write_nonblock',
                    count: data.length, written: written
        end

        def start_read_on_write
          return if @read_on_write
          # This captures an OpenSSL read wanting a write
          @multiplexer.stop_read self
          @multiplexer.wait_write self if @write_immediately
          @write_immediately = false
          @read_on_write = true
          log_debug 'OpenSSL wants read on write'
        end

        def stop_read_on_write
          return unless @read_on_write
          @read_on_write = false
          @multiplexer.wait_read self if @read_active
          @multiplexer.stop_write self unless @write_immediately
          @write_immediately = true
        end

        def start_write_on_read
          return if @write_on_read
          @multiplexer.stop_write self unless @write_immediately
          @multiplexer.wait_read self unless @read_active
          @write_immediately = true
          @write_on_read = true
          log_debug 'OpenSSL wants write on read'
        end

        def stop_write_on_read
          return unless @write_on_read
          @multiplexer.stop_read self unless @read_active
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
    end # ::IOReactor
  end # ::Mixins
end # ::IOMultiplex
