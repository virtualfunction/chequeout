require 'spec_helper'

describe :tax do
  # TODO: Test event hooks?

  [ Order, PurchaseItem, Product ].each do |model|
    specify { expect(model.features).to include(:taxation) }
  end

  describe 'calcuations' do
    let(:order) { FactoryGirl.create :filled_basket_order }

    it 'perform basic calculations' do
      expect(order.calculate_tax_cost).to eq(GBP '4.00')
    end

    it 'integrates with purchased items' do
      purchase = order.purchase_items.first
      expect('%0.2f' % purchase.tax_rate).to eq '0.20'
      expect(purchase.tax_cost).to eq(GBP '4.00')
    end

    it 'adds taxtion as fee adjustment' do
      order.calculate_tax
      expect(order.tax_scope.count).to be > 0
    end
  end
end
