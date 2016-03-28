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
        extra = {}
        extra = diagnostics.call unless diagnostics.nil?
        log_warn \
          'Slow ' + func.to_s,
          :duration_ms => duration,
          :client => monitor.value.id,
          **extra
      end
    end # ::LogSlow
  end # ::Mixins
end # ::IOMultiplex
