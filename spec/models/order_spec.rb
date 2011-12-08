require File.expand_path('../../../spec/spec_helper', __FILE__)

describe Order do

  let(:items) { order.purchase_items }
  let(:purchase) { items.first }
  # Our test 'spy' order will record event counts into this
  let(:history) { Hash.new 0 }
  # Make this order also double up as an event spy
  let :order do  
    history.clear
    item = history # Scoping issue
    FactoryGirl.create(:filled_basket_order).tap do |order|
      order.singleton_class.class_eval do 
        Order.event_list.each do |event|
          set_callback event, :before do 
            item[event] += 1
          end
        end
      end
    end
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
      expect { order.add purchase, :quantity => 1 }.to change { order.reload.sub_total }.by(GBP '9.99')
    end
    
    specify do
      expect { purchase.destroy }.to change { order.reload.sub_total }.to(GBP '0.00')
    end
  end
  
  describe 'refund' do
    before :all do
      order.singleton_class.class_eval do 
        def merchant_refund!(amount)
          true
        end
      end
      order.success!
      order.refund!
    end
    
    it('is successful') { order.status == 'success' }
    it('triggers a refund event') { history[:refund_payment].should == 1 }
    # it 'marks the refund as a fee adjustment' do
    #   order.fee_adjustments.refund.first.price.should == GBP('-19.98')
    # end
  end
  
  describe 'checkout' do
    describe 'successful (bypasing merchant)' do
      before :all do
        order.stub(:skip_merchant_processing?) { true }
        order.checkout!
      end
      
      specify { order.status.should == 'success' }
      specify { history[:process_payment].should == 1 }
      specify { history[:completed_payment].should == 1 }
      specify { history[:merchant_processing].should == 0 }
    end

    describe 'merchant processing failure' do
      before :all do
        order.stub(:merchant_processing!) { false }
        order.checkout!
      end

      specify { order.status.should == 'failed' }
      specify { history[:process_payment].should == 1 }
      specify { history[:failed_payment].should == 1 }
      specify { history[:merchant_processing].should == 1 }
    end
    
    describe '`basket modify` event' do
      # Make this putchase also do event spy ops
      let :historic_purchase do
        history.clear
        item = history # Scoping issue
        purchase.singleton_class.class_eval do 
          PurchaseItem.event_list.each do |event|
            set_callback event, :before do 
              item[event] += 1
            end
          end
        end
        purchase
      end

      before :each do
        historic_purchase.update_attributes :quantity => 3
        historic_purchase.destroy
      end
      
      specify { history[:basket_modify].should == 2 }
    end
    
    describe 'address events' do
      before :each do
        # Note we do this to ensure we use the tracked order object
        [ :shipping_address, :billing_address ].each do |address|
          FactoryGirl.create address, :addressable => order
        end
      end
      
      it 'triggers events' do
        events = {
          :create_shipping_address => 1,
          :create_billing_address => 1,
          :save_shipping_address => 1,
          :save_billing_address => 1,
          :create_address => 2,
          :save_address => 2,
        }
        history.slice(*events.keys).should == events
      end
    end
  end
end
