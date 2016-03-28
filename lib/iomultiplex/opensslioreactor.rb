# encoding: utf-8

# Copyright 2014 Jason Woods.
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

require 'iomultiplex/bufferedioreactor'
require 'iomultiplex/mixins/openssl'

module IOMultiplex
  # OpenSSLIOReactor wraps an OpenSSL IO object which receives TLS connections
  class OpenSSLIOReactor < BufferedIOReactor
    include Mixins::OpenSSL

    def initialize(io, id = nil, ssl_ctx = nil)
      # OpenSSL is implicitly read/write due to key-exchange
      super io, 'rw', id
      initialize_openssl ssl_ctx
    end

    protected

    def read_nonblock(n)
      log_debug 'SSL read_nonblock', count: n
      @ssl.read_nonblock n
    end

    def write_nonblock(data)
      log_debug 'SSL write_nonblock', count: data.length
      @ssl.write_nonblock data
    end

    def read_action
      return super if @handshake_completed

      process_handshake
      super
    end
  end

  # OpenSSLUpgradingIOReactor wraps an IO object that acts like a regular
  # IOReactor but can be upgraded to a TLS connection mid-connection
  class OpenSSLUpgradingIOReactor < BufferedIOReactor
    include Mixins::OpenSSL

    def initialize(io, id = nil)
      # OpenSSL is implicitly read/write due to key-exchange
      super io, 'rw', id
      @ssl_enabled = false
    end

    def start_ssl(ssl_ctx)
      fail 'SSL already started', nil if @ssl_enabled
      initialize_openssl ssl_ctx
      @ssl_enabled = true
      log_debug 'Upgrading connection to SSL'
      nil
    end

    def can_write_immediately?
      !@ssl_enabled
    end

    private

    def read_nonblock(n)
      return super unless @ssl_enabled
      log_debug 'SSL read_nonblock', count: n
      @ssl.read_nonblock n
    end

    def write_nonblock(data)
      return super unless @ssl_enabled
      log_debug 'SSL write_nonblock', count: data.length
      @ssl.write_nonblock data
    end

    def read_action
      return super unless @ssl_enabled && !@handshake_completed

      process_handshake
      super
    end
  end
end
