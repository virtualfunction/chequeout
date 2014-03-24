FactoryGirl.define do
  sequence :order_session do |seq|
    'Test Session %d %f' % [ seq, rand ]
  end

  factory :order do
    status          'basket'
    session_uid     { FactoryGirl.sequence_by_name(:order_session).next }
    billing_address { FactoryGirl.build :billing_address }
    currency        { GBP(0.00).currency }

    factory :filled_basket_order do
      after :create do |order|
        product = FactoryGirl.create :product
        order.add product, quantity: 2
      end

      factory :shipped_order do
        tracking_code     nil
        dispatch_date     { Time.now }
        shipping_address  { FactoryGirl.build :shipping_address }
      end
    end
  end
end
