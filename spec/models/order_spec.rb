require 'spec_helper'

describe Order do

  ADDRESS_EVENTS = {
    create_shipping_address:  1,
    create_billing_address:   1,
    save_shipping_address:    1,
    save_billing_address:     1,
    # This happens for each address
    create_address:           2,
    save_address:             2,
  }.freeze

  let(:items)     { order.purchase_items }
  let(:purchase)  { items.first.spy_on :basket_modify }

  let :order do
    FactoryGirl.create(:filled_basket_order).spy_on \
      :process_payment,
      :completed_payment,
      :merchant_processing,
      *(Order.event_list.to_a + ADDRESS_EVENTS.keys).collect(&:to_sym).uniq
  end

  it 'understands the concept of zero' do
    expect(order.zero.cents).to be_zero
  end

  it 'calculates the correct total' do
    expect(items.collect(&:price).sum).to eq(GBP '9.99')
    expect(items.collect(&:total_price).sum).to eq(GBP '19.98')
  end

  specify { expect(order).to be_basket }
  specify { expect(order.calculated_total).to eq(GBP '19.98') }
  specify { expect(order.total_price).to eq(GBP '19.98') }

  describe 'order total' do
    specify do
      expect { order.add purchase.brought_item, quantity: 1 }.to change { order.reload.sub_total }.by(GBP '-9.99')
    end

    specify do
      expect { purchase.destroy }.to change { order.reload.sub_total }.to(GBP '0.00')
    end
  end

  describe 'checkout' do
    describe 'successful (bypasing merchant)' do
      before do
        allow(order).to receive(:skip_merchant_processing?) { true }
        order.checkout!
      end

      specify { expect(order).to be_success }
      specify { expect(order.event_history[:process_payment]).to eq 1 }
      specify { expect(order.event_history[:completed_payment]).to eq 1 }
      specify { expect(order.event_history[:merchant_processing]).to be_zero }
    end

    describe 'merchant processing failure' do
      before do
        allow(order).to receive(:merchant_processing!) { false }
        order.checkout!
      end

      specify { expect(order).to be_failed }
      specify { expect(order.event_history[:process_payment]).to eq 1 }
      specify { expect(order.event_history[:failed_payment]).to eq 1 }
      specify { expect(order.event_history[:merchant_processing]).to eq 1 }
    end

    describe '`basket modify` event' do
      before do
        purchase.update quantity: 3
        purchase.destroy
      end

      specify { expect(purchase.event_history[:basket_modify]).to eq 2 }
    end

    describe 'address events' do
      before do
        # Note we do this to ensure we use the tracked order object
        [ :shipping_address, :billing_address ].each do |address|
          FactoryGirl.create address, addressable: order
        end
      end

      it 'triggers events' do
        expect(order.event_history.slice *ADDRESS_EVENTS.keys).to eq ADDRESS_EVENTS
      end
    end
  end
end
