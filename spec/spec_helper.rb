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
