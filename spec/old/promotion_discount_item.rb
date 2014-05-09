class PromotionDiscountItem < ActiveRecord::Base
  include Chequeout::Offer::PromotionDiscountableItem
end
