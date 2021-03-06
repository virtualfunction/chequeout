require 'spec_helper'

describe :inventory do

  describe Product do
    it 'has inventory tracking' do
      expect(Product.features).to include(:inventory)
    end
  end

  describe PurchaseItem do
    it 'has inventory tracking' do
      expect(PurchaseItem.features).to include(:inventory)
    end
  end

  describe 'processing' do
    let(:order) { FactoryGirl.create :filled_basket_order }
    let(:purchase) { order.purchase_items.first }
    let(:item) { purchase.brought_item.spy_on *Product.event_list }

    it 'has managed products' do
      expect(item).to respond_to(:in_stock?)
    end

    it 'tracks purchased quantities' do
      expect(purchase).to respond_to(:set_quantity)
    end

    it 'changes item stock levels when purchase quantity is changed' do
      expect { purchase.update set_quantity: 1 }.to change { item.reload.stock_levels }.by 1
    end

    it 'increases stock levels when removing purchases' do
      expect { purchase.destroy }.to change { item.reload.stock_levels }.by 2
    end

    it 'decreases stock levels when purchasing' do
      expect { order.add item, set_quantity: 3 }.to change { item.reload.stock_levels }.by -1
    end

    describe 'events' do
      it 'triggers an `out_of_stock` event' do
        item.update stock_levels: 1
        item.stock_levels = 0
        expect(item.event_history[:out_of_stock]).to eq(1)
      end

      it 'triggers a `stock_replenished` event' do
        item.update stock_levels: 0
        item.stock_levels = 1
        expect(item.event_history[:stock_replenished]).to eq(1)
      end
    end
  end
end
