FactoryGirl.define do
  factory :purchase_item do
    order         { Order.first   || FactoryGirl.build(:order)    }
    brought_item  { Product.first || FactoryGirl.create(:product) }
    quantity      2
  end
end
