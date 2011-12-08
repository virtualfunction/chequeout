require File.expand_path('../../../spec/spec_helper', __FILE__)

Shipping = Chequeout::Shipping

describe Shipping do

  # TODO: Test event hooks?
  
  specify { Order.should be < Shipping::TrackableOrder }
  specify { Order.should be < Shipping::CalculateByWeight }
  specify { Product.should be < Shipping::Item }

  module DummyWeightShipping
    def shipping_weight_price(weight)
      GBP '5.99'
    end
  end

  describe 'process' do
    let :order do
      FactoryGirl.create(:filled_basket_order).extend DummyWeightShipping
    end
    
    it 'performs basic calculations' do
      order.calculate_shipping_cost.should == GBP('5.99')
    end
    
    it 'adds shipping as fee adjustment' do
      order.calculate_shipping
      order.shipping_scope.count.should > 0
    end
  end
end
