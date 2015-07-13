require 'active_support/all'
require 'active_record'
require 'monetize/core_extensions'
require 'forwardable'
require 'monetize'
require 'money'
require 'set'

I18n.enforce_available_locales = false

module Chequeout
  module Core; end

  require 'core/features_dsl'
  require 'core/attr_scoped'
  require 'core/currency_extensions'
  require 'core/eventable'
  require 'core/polymorphic_uniqueness'

  extend FeaturesDsl::Tools
  load
end
