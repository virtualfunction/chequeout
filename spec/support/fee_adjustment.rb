class FeeAdjustment < ActiveRecord::Base
  include Chequeout::FeeAdjustment
  include Chequeout::Offer::DiscountedProductAdjustment
  include Chequeout::Offer::DiscountCodeAdjustment
  include Chequeout::Inventory::FeeAdjustment
end
