module Chequeout
  module FeaturesDsl
  end
end

require 'set'
require 'yaml'
require 'rubygems'
require 'active_support/all'
require './lib/core/features_dsl.rb'

Chequeout.class_exec do
  extend Chequeout::FeaturesDsl::Tools
end

Chequeout.define_model :purchase_item do |item|
  def test
    'PurchaseItem'
  end
  puts :purchase_item
  class << self
    def related_to(klass)
      puts 'related_to %s' % klass.name
    end
  end
end

Chequeout.define_model :product do |item|
  # Is class_exec'ed into model

  item.database_strcuture do |table|
    # ... forms DDL except indexes (needs alter table)
  end
  puts :product
  item.model(:purchase_item).related_to self
end

Chequeout.define_model :address do |item|
  def meh
    'Meh!'
  end

  item.database_strcuture do |table|
    table.string :name, :location, :phone
  end
end

Chequeout.define_feature :taxation do |feature|
  feature.behaviour_for :product do |item|
    item.database_strcuture do |table|
      table.string :name, :description
    end
    puts :tax
    item.model(:purchase_item).related_to self
  end

  feature.behaviour_for :order do |item|
    item.database_strcuture do |table|
      table.datetime :created_at
    end
  end
end

Chequeout.define_feature :shipping do |feature|
  feature.behaviour_for :address do |item|
    def trackable?
    end
  end
end

class Address
end

class Product
end

class PurchaseItem
  class << self
    def related_to(klass)
      puts 'OLD_related_to %s' % klass.name
    end
  end
end

context = Chequeout.apply :shopping_cart do |cart|
  cart.model :product, 'Product'
  cart.model :address, 'Address'
  cart.model :purchase_item # Implied syntax
  cart.apply_feature :taxation
  # cart.apply_feature :shipping
  # cart.apply_feature :offer
  # cart.apply_feature :inventory
end



puts Address.new.meh
puts Address.new.respond_to? :trackable?
puts PurchaseItem.new.test
puts context.applied_database_scheme.to_yaml
