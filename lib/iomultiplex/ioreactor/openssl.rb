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

require 'iomultiplex/mixins/ioreactor/openssl'

module IOMultiplex
  class IOReactor
    # Wraps an OpenSSL IO object which receives TLS connections
    class OpenSSL < TCPSocket
      include Mixins::IOReactor::OpenSSL

      def initialize(ssl_ctx = nil, id = nil, io = nil)
        super id, io
        initialize_ssl ssl_ctx
      end

      protected

      def read_nonblock(n)
        ssl_read_nonblock n
      end

      def write_nonblock(data)
        ssl_write_nonblock data
      end

      def read_action
        return super if @handshake_completed

        process_handshake
        super
      end
    end # ::OpenSSL

    # OpenSSLUpgrading wraps an IO object that acts like a regular
    # IOReactor but can be upgraded to a TLS connection mid-connection
    class OpenSSLUpgrading < TCPSocket
      include Mixins::IOReactor::OpenSSL

      def initialize(id = nil, io = nil)
        # OpenSSL is implicitly read/write due to key-exchange so we ignore the
        # mode parameter
        super id, io
        @ssl_enabled = false
      end

      def start_ssl(ssl_ctx)
        raise 'SSL already started', nil if @ssl_enabled
        initialize_ssl ssl_ctx
        include Mixins::IOReactor::Buffered
        @ssl_enabled = true
        log_debug 'Upgrading connection to SSL'
        nil
      end

      private

      def read_nonblock(n)
        return super(n) unless @ssl_enabled
        ssl_read_nonblock n
      end

      def write_nonblock(data)
        return super(data) unless @ssl_enabled
        ssl_write_nonblock data
      end

      def read_action
        return super unless @ssl_enabled && !@handshake_completed

        process_handshake
        super
      end
    end # ::OpenSSLUpgrading
  end # ::IOReactor
end # ::IOMultiplex
