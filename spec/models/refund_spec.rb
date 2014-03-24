require 'spec_helper'

Refund = Chequeout::Refundable

describe Refund do
  let(:order) { FactoryGirl.create(:filled_basket_order).spy_on :refund_payment }
  let(:date)  { Time.parse 'January 2015' }

  describe Order do
    it 'has refund management' do
      expect(Order).to be < Refund::Order
    end
  end

  describe PurchaseItem do
    it 'has refund management' do
      expect(PurchaseItem).to be < Refund::Purchase
    end
  end

  describe 'purchase' do
    let(:purchase) { order.purchase_items.first }

    describe 'everything' do
      let(:refund) { purchase.refund! }

      it 'created an entry' do
        expect(refund).to be_a(FeeAdjustment)
        expect(refund.quantity).to eq purchase.quantity
        expect(refund.related_adjustment_item).to eq purchase
        expect(refund.price).to eq(GBP '-19.98')
        expect(refund.processed_date).to be nil
        expect(purchase.refund_items.first).to eq refund
        expect(order.reload).to be_part_refunded
      end
    end

    describe 'partial' do
      let :refund do
        purchase.refund! \
          quantity:     1,
          display_name: 'Part refund',
          processed:    date
      end

      it 'created an entry' do
        expect(refund.quantity).to eq 1
        expect(refund.price).to eq(GBP '-9.99')
        expect(refund.display_name).to eq 'Part refund'
        expect(refund.processed_date).to eq date
        expect(order.reload).to be_part_refunded
      end
    end
  end

  describe 'order' do
    describe 'full' do
      let(:refunds) { order.full_refund! }
      let(:refund)  { refunds.first }

      it 'triggers a refund event' do
        refund
        expect(order.event_history[:refund_payment]).to eq 1
      end

      it 'creates an entry' do
        expect(refund).to be_a(FeeAdjustment)
        expect(refund.price).to eq(GBP '-19.98')
        expect(refund.processed_date).to be nil
        expect(refunds.count).to eq 1
        expect(refunds.first).to eq refund
        expect(order.reload).to be_fully_refunded
      end
    end

    describe 'general' do
      let(:total)   { order.calculated_total }
      let(:refunds) { order.fee_adjustments.refund }
      let :refund do
        order.general_refund! \
          display_name:   'General refund',
          processed_date: date,
          amount:         total
      end

      it 'triggers a refund event' do
        refund
        expect(order.event_history[:refund_payment]).to eq 1
      end

      it 'creates an entry' do
        expect(refund).to be_a(FeeAdjustment)
        expect(refund.price).to eq(total * -1)
        expect(refund.processed_date).to eq date
        expect(refunds.count).to eq 1
        expect(refunds.first).to eq refund
        expect(order.reload).to be_fully_refunded
      end
    end
  end
end
