require 'simplecov'
SimpleCov.start

module IOMultiplex
  # Custom WaitX objects we can raise
  # Need it this way as, e.g. IO::WaitReadable is a module not an object
  class WaitReadable < Exception
    include IO::WaitReadable
  end

  # Custom WaitWritable
  class WaitWritable < Exception
    include IO::WaitWritable
  end
end

# Returns next discardable port that won't be reused in tests
# Since we successfuly connect we end up in TIME_WAIT so cannot re-use the
# listen part for a few seconds or so, so use a different one each time
module PortManagement
  def discardable_port
    port = RSpec.configuration.next_discardable_port
    RSpec.configuration.next_discardable_port += 1
    port
  end

  def reusable_port
    12_345
  end
end

RSpec.configure do |config|
  config.add_setting :next_discardable_port
  config.before(:suite) do
    RSpec.configuration.next_discardable_port = 20_000 + rand(40_000)
  end
  config.include PortManagement
end
