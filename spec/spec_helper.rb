# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'
ROOT = File.expand_path '..', __FILE__
# require root + '/dummy/config/environment.rb'
require 'rubygems'
require ROOT + '/../lib/chequeout'
require 'active_support/dependencies'
require 'factory_girl_rails'
# require 'ruby-debug/debugger'

Chequeout::Database.class_eval do
  def self.root
    File.expand_path '..', ROOT
  end
end

# Use SQLite for our test DB
ActiveRecord::Base.establish_connection \
  :database => ROOT + '/../test.sqlite3',
  :adapter  => 'sqlite3',
  :timeout  => 5000

# Load support files and migrate
ActiveSupport::Dependencies.autoload_paths << ROOT + '/../spec/support'
Dir[ROOT + '/../spec/{factories,support}/**/*.rb'].each { |file| require_dependency file }
ActiveRecord::Migrator.migrate ROOT + '/migrations/'

# Rails.backtrace_cleaner.remove_silencers!

RSpec.configure do |config|
  # Remove this line if you don't want RSpec's should and should_not
  # methods or matchers
  require 'rspec/expectations'
  config.include RSpec::Matchers

  # == Mock Framework
  config.mock_with :rspec
end