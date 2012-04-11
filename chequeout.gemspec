lib = File.expand_path '../lib/', __FILE__
$:.unshift(lib) unless $:.include?(lib)

require 'bundler'
require 'version'

Gem::Specification.new do |gem|  
  gem.name          = 'chequeout'
  gem.version       = Chequeout::VERSION
  gem.platform      = Gem::Platform::RUBY
  gem.authors       = ['Jason Earl']
  gem.email         = 'jason@hybd.net'
  gem.homepage      = 'http://github.com/virtualfunction/chequeout'
  gem.summary       = 'A simple and extendable core for developing basic Rails e-commerce systems.'
  gem.description   = 'Chequeout provides some basic model functionallity for e-commerce cart systems, to aid speed up development of cart systems.'
  gem.require_path  = 'lib'
  gem.files = 
    %w(README.rdoc Gemfile Rakefile MIT-LICENSE chequeout.gemspec) + 
    Dir.glob('{lib,spec}/**/*')
  
  gem.add_dependency 'activesupport', '>= 3'
  gem.add_dependency 'activerecord',  '>= 3'
  gem.add_dependency 'acts_as_list'
  gem.add_dependency 'money',         '>= 5'
end
