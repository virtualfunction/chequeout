require File.expand_path('../../../spec/spec_helper', __FILE__)

Inventory = Chequeout::Inventory

describe Inventory do
  
  describe Product do
    it 'has inventory tracking' do
      Product.should be < Inventory::ItemManagement
    end
  end

  describe PurchaseItem do
    it 'has inventory tracking' do
      PurchaseItem.should be < Inventory::Purchaseable
    end
  end
  
  describe 'processing' do
    let(:order) { FactoryGirl.create :filled_basket_order }
    let(:purchase) { order.purchase_items.first }
    let(:item) { purchase.brought_item.spy_on *Product.event_list }

    it 'has managed products' do
      item.should be_kind_of(Inventory::ItemManagement)
    end

    it 'tracks purchased quantities' do
      purchase.should be_kind_of(Inventory::Purchaseable)
    end
    
    it 'changes item stock levels when purchase quantity is changed' do
      expect { purchase.update_attributes :quantity => 1 }.to change { item.stock_levels }.by 1
    end

    it 'increases stock levels when removing purchases' do
      expect { purchase.destroy }.to change { item.reload.stock_levels }.by 2
    end

    it 'decreases stock levels when purchasing' do
      expect { order.add item, :quantity => 3 }.to change { item.reload.stock_levels }.by -1
    end

    describe 'events' do 
      it 'triggers an `out_of_stock` event' do
        item.update_attribute :stock_levels, 1
        item.stock_levels = 0
        item.event_history[:out_of_stock].should == 1
      end
      
      it 'triggers a `stock_replenished` event' do
        item.update_attribute :stock_levels, 0
        item.stock_levels = 1
        item.event_history[:stock_replenished].should == 1
      end
    end
  end
end
