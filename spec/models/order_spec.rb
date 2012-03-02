require File.expand_path('../../../spec/spec_helper', __FILE__)

describe Order do

  ADDRESS_EVENTS = {
    :create_shipping_address  => 1,
    :create_billing_address   => 1,
    :save_shipping_address    => 1,
    :save_billing_address     => 1,
    # This happens for each address
    :create_address           => 2,
    :save_address             => 2,
  }.freeze

  let(:items)     { order.purchase_items }
  let(:purchase)  { items.first.spy_on :basket_modify }
  
  y [ :ADDRESS, ADDRESS_EVENTS.keys ]
  
  let :order do  
    FactoryGirl.create(:filled_basket_order).spy_on \
      :process_payment, 
      :completed_payment, 
      :merchant_processing, 
      *(Order.event_list.to_a + ADDRESS_EVENTS.keys).collect(&:to_sym).uniq
  end
  
  it 'understands the concept of zero' do
    order.zero.cents.should == 0
  end
  
  it 'calculates the correct total' do
    items.collect(&:price).sum.should == GBP('9.99')
    items.collect(&:total_price).sum.should == GBP('19.98')
  end
  
  specify { order.status.should == 'basket' }
  specify { order.calculated_total.should == GBP('19.98') }
  specify { order.total_price.should == GBP('19.98') }
  
  describe 'order total' do
    specify do
      expect { order.add purchase.brought_item, :quantity => 1 }.to change { order.reload.sub_total }.by(GBP '-9.99')
    end
    
    specify do
      expect { purchase.destroy }.to change { order.reload.sub_total }.to(GBP '0.00')
    end
  end
  
  describe 'checkout' do
    describe 'successful (bypasing merchant)' do
      before :all do
        order.stub(:skip_merchant_processing?) { true }
        order.checkout!
      end
      
      specify { order.status.should == 'success' }
      specify { order.event_history[:process_payment].should == 1 }
      specify { order.event_history[:completed_payment].should == 1 }
      specify { order.event_history[:merchant_processing].should == 0 }
    end

    describe 'merchant processing failure' do
      before :all do
        order.stub(:merchant_processing!) { false }
        order.checkout!
      end

      specify { order.status.should == 'failed' }
      specify { order.event_history[:process_payment].should == 1 }
      specify { order.event_history[:failed_payment].should == 1 }
      specify { order.event_history[:merchant_processing].should == 1 }
    end
    
    describe '`basket modify` event' do
      before :each do
        purchase.update_attributes :quantity => 3
        purchase.destroy
      end
      
      specify { purchase.event_history[:basket_modify].should == 2 }
    end
    
    describe 'address events' do
      before :each do
        # Note we do this to ensure we use the tracked order object
        [ :shipping_address, :billing_address ].each do |address|
          FactoryGirl.create address, :addressable => order
        end
      end
      
      it 'triggers events' do
        order.event_history.slice(*ADDRESS_EVENTS.keys).should == ADDRESS_EVENTS
      end
    end
  end
end
