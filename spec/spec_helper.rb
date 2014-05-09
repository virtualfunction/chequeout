# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'
require 'rubygems'
require 'factory_girl_rails'
require 'rspec/expectations'
require './lib/chequeout'

# Use SQLite for our test DB
ActiveRecord::Base.establish_connection \
  database: Chequeout.base_folder + '/test.sqlite3',
  adapter:  'sqlite3',
  timeout:  5000

ActiveRecord::Base.logger = Logger.new StringIO.new

# Load support files and migrate
ActiveSupport::Dependencies.autoload_paths << Chequeout.base_folder + '/spec/support'
Dir[Chequeout.base_folder + '/spec/{factories,support}/**/*.rb'].each { |file| require file }
ActiveRecord::Migrator.migrate Chequeout.base_folder + '/spec/migrations/'

# [ Address, Order, PurchaseItem, PromotionDiscountItem, Promotion, FeeAdjustment ].each &:delete_all

RSpec.configure do |config|
  # Remove this line if you don't want RSpec's should and should_not methods or matchers
  config.include RSpec::Matchers

  # == Mock Framework
  config.mock_with :rspec
end
