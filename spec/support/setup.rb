Base = ActiveRecord::Base

class Address < Base
end

class FeeAdjustment < Base
end

class Order < Base
end

class Product < Base
end

class Promotion < Base
end

class PromotionDiscountItem < Base
end

class PurchaseItem < Base
end

Context = Chequeout.apply :shopping_cart do |cart|
  cart.model :address
  cart.model :fee_adjustment
  cart.model :order
  cart.model :product
  cart.model :promotion
  cart.model :promotion_discount_item
  cart.model :purchase_item
  cart.apply_feature :taxation
  cart.apply_feature :shipping
  cart.apply_feature :offer
  cart.apply_feature :inventory
  cart.apply_feature :refundable
end
