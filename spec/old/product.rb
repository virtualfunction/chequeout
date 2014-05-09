class Product < ActiveRecord::Base
  include Chequeout::Product
  include Chequeout::Inventory::ItemManagement
  include Chequeout::Shipping::Item
  include Chequeout::Taxation::Item

  Money.composition_on self, :price
end
