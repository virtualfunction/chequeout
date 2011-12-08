class PurchaseItem < ActiveRecord::Base
  include Chequeout::PurchaseItem
  include Chequeout::Inventory::Purchaseable
  include Chequeout::Taxation::Purchase
  include Chequeout::Refundable::Purchase
end
