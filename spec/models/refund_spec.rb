require File.expand_path('../../../spec/spec_helper', __FILE__)

Refund = Chequeout::Refundable

describe Refund do
  let(:order) { FactoryGirl.create(:filled_basket_order).spy_on :refund_payment }
  let(:date)  { Time.parse 'January 2015' }

  describe Order do
    it 'has refund management' do
      Order.should be < Refund::Order
    end
  end

  describe PurchaseItem do
    it 'has refund management' do
      PurchaseItem.should be < Refund::Purchase
    end
  end

  describe 'purchase' do
    let(:purchase) { order.purchase_items.first }
    
    describe 'everything' do
      let(:refund) { purchase.refund! }

      it 'created an entry' do
        refund.should be_a(FeeAdjustment)
        refund.quantity.should == purchase.quantity
        refund.related_adjustment_item.should == purchase
        refund.price.should == GBP('-19.98')
        refund.processed_date.should be_nil
        purchase.refund_items.first.should == refund
        order.reload.status.should == 'part_refunded'
      end
    end
    
    describe 'partial' do
      let :refund do 
        purchase.refund! \
          :quantity     => 1, 
          :display_name => 'Part refund',
          :processed    => date
      end
      
      it 'created an entry' do
        refund.quantity.should == 1
        refund.price.should == GBP('-9.99')
        refund.display_name.should == 'Part refund'
        refund.processed_date.should == date
      end
    end
  end
  
  describe 'order' do
    describe 'full' do
      let(:refunds) { order.full_refund! }
      let(:refund)  { refunds.first }

      it 'triggers a refund event' do
        refund
        order.event_history[:refund_payment].should == 1
      end
      
      it 'creates an entry' do 
        refund.should be_a(FeeAdjustment)
        refund.price.should == GBP('-19.98')
        refund.processed_date.should be_nil
        refunds.count.should == 1
        refunds.first.should == refund
        order.reload.status.should == 'fully_refunded'
      end
    end
    
    describe 'general' do
      let(:total)   { order.calculated_total }
      let(:refunds) { order.fee_adjustments.refund }
      let :refund do
        order.general_refund! \
          :display_name   => 'General refund',
          :processed_date => date,
          :amount         => total
      end

      it 'triggers a refund event' do
        refund
        order.event_history[:refund_payment].should == 1
      end
      
      it 'creates an entry' do
        refund.should be_a(FeeAdjustment)
        refund.price.should == total * -1
        refund.processed_date.should == date
        refunds.count.should == 1
        refunds.first.should == refund
        order.reload.status.should == 'fully_refunded'
      end
    end
  end
end
