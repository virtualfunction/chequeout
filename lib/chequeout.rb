require 'active_support'
require 'active_support/all'
require 'active_record'
require 'monetize/core_extensions'
require 'monetize'
require 'money'
require 'set'

I18n.enforce_available_locales = false

module Chequeout
  module Core; end

  require 'core/attr_scoped'
  require 'core/concerned'
  require 'core/currency_extensions'
  require 'core/database'
  require 'core/eventable'
  require 'core/polymorphic_uniqueness'

  MODELS = %w[ Address FeeAdjustment Order Product PurchaseItem ].each do |model|
    autoload model.to_sym, 'chequeout/%s' % model.underscore
  end
  TRAITS = %w[ Inventory Offer Shipping Taxation Refundable ].each do |trait|
    autoload trait.to_sym, 'traits/%s' % trait.underscore
  end

  def self.load_all
    (MODELS + TRAITS).each { |item| const_get item }
  end
end
