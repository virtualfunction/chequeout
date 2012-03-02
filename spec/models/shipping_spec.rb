require File.expand_path('../../../spec/spec_helper', __FILE__)

Shipping = Chequeout::Shipping

describe Shipping do

  specify { Order.should be   < Shipping::TrackableOrder }
  specify { Order.should be   < Shipping::CalculateByWeight }
  specify { Product.should be < Shipping::Item }

  module DummyWeightShipping
    def shipping_weight_price(weight)
      GBP '5.99'
    end
  end
  
  let :order do
    FactoryGirl.create(:filled_basket_order).
      extend(DummyWeightShipping).
      spy_on(:dispatched)
  end

  describe 'process' do
    it 'performs basic calculations' do
      order.calculate_shipping_cost.should == GBP('5.99')
    end
    
    it 'adds shipping as fee adjustment' do
      order.calculate_shipping
      order.shipping_scope.count.should > 0
    end
  end
  
  describe 'dispatch' do
    before { order.success! }
    
    it 'can be marked as dispatchable' do
      order.dispatched?.should be_false
      lambda { order.dispatched! }.should(change(Order.dispatched, :count).by(1))
      order.dispatched?.should be_true
      order.dispatch_date.should be_a(Time)
      order.event_history[:dispatched].should == 1
    end
  end

  describe 'tracking' do
    it 'can be record a tracking code' do
      order.dispatch_with_tracking! 'ABC'
      order.dispatched?.should be_true
      order.tracking_code.should == 'ABC'
    end
  end
end
