# encoding: utf-8

# Copyright 2014-2016 Jason Woods.
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

require 'iomultiplex'
require 'iomultiplex/ioreactor/openssl'

RSpec.describe IOMultiplex::IOReactor::OpenSSL do
  before :example do
    @ssl_ctx = OpenSSL::SSL::SSLContext.new
  end
end

RSpec.describe IOMultiplex::IOReactor::OpenSSLUpgrading do
end
