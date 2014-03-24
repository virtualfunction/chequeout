require 'spec_helper'

Shipping = Chequeout::Shipping

describe Shipping do

  specify { expect(Order).to be   < Shipping::TrackableOrder }
  specify { expect(Order).to be   < Shipping::CalculateByWeight }
  specify { expect(Product).to be < Shipping::Item }

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
      expect(order.calculate_shipping_cost).to eq(GBP '5.99')
    end

    it 'adds shipping as fee adjustment' do
      order.calculate_shipping
      expect(order.shipping_scope.count).to be > 0
    end
  end

  describe 'dispatch' do
    before { order.success! }

    it 'can be marked as dispatchable' do
      expect(order.dispatched?).to be false
      expect { order.dispatched! }.to change(Order.dispatched, :count).by(1)
      expect(order.dispatched?).to be true
      expect(order.dispatch_date).to be_a(Time)
      expect(order.event_history[:dispatched]).to eq 1
    end
  end

  describe 'tracking' do
    it 'can be record a tracking code' do
      order.dispatch_with_tracking! 'ABC'
      expect(order.dispatched?).to be true
      expect(order.tracking_code).to eq 'ABC'
    end
  end
end
