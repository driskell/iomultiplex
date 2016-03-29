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

module IOMultiplex
  module Mixins
    # LogSlow mixin to log slow function calls
    module LogSlow
      protected

      # Wrap a method and report to the logger if it runs slowly
      def log_slow(func, args = [], max_duration = 100, diagnostics = nil)
        sub_start_time = Time.now
        func.call(*args)
        duration = ((Time.now - sub_start_time) * 1000).to_i
        return unless duration > max_duration
        extra = {
          :duration_ms => duration,
          :client => monitor.value.id
        }
        extra = diagnostics.call unless diagnostics.nil?
        log_warn \
          'Slow ' + func.to_s,
          extra
      end
    end # ::LogSlow
  end # ::Mixins
end # ::IOMultiplex
