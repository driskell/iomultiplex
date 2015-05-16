Gem::Specification.new do |gem|
  gem.name              = 'iomultiplex'
  gem.version           = '0.9'
  gem.description       = 'NIO4R IO reactor library'
  gem.summary           = 'An IO reactor, utilising NIO4R, supporting OpenSSL and multiple IO threads'
  gem.homepage          = 'https://github.com/driskell/iomultiplex'
  gem.authors           = ['Jason Woods']
  gem.email             = ['devel@jasonwoods.me.uk']
  gem.licenses          = ['GPL']
  gem.rubyforge_project = 'nowarning'
  gem.require_paths     = ['lib']
  gem.files             = %w(
    lib/iomultiplex/iomultiplex.rb
  )

  gem.add_runtime_dependency 'nio4r',      ['~> 1.0', '>= 1.0.1']
end
