lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'iomultiplex/version'

Gem::Specification.new do |gem|
  gem.name              = 'iomultiplex'
  gem.version           = IOMultiplex::VERSION
  gem.description       = 'NIO4R IO reactor library'
  gem.summary           =
    'An event-loop experiment designed for high throughput across many ' \
      'clients, with minimal and deterministic memory usage.'
  gem.homepage          = 'https://github.com/driskell/iomultiplex'
  gem.authors           = ['Jason Woods']
  gem.email             = ['devel@jasonwoods.me.uk']
  gem.licenses          = ['GPL']
  gem.rubyforge_project = 'nowarning'
  gem.require_paths     = ['lib']
  gem.files             = Dir['lib/**/*']

  gem.add_runtime_dependency 'cabin', '~> 0.6'
  gem.add_runtime_dependency 'nio4r', ['~> 1.0', '>= 1.0.1']
end
