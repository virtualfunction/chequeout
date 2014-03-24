require 'spec_helper'

Tax = Chequeout::Taxation

describe Tax do
  # TODO: Test event hooks?

  specify { expect(Order).to be < Tax::Order }
  specify { expect(PurchaseItem).to be < Tax::Purchase }
  specify { expect(Product).to be < Tax::Item }

  describe 'calcuations' do
    let(:order) { FactoryGirl.create :filled_basket_order }

    it 'perform basic calculations' do
      expect(order.calculate_tax_cost).to eq(GBP '4.00')
    end

    it 'integrates with purchased items' do
      purchase = order.purchase_items.first
      expect(purchase.tax_rate.to_s).to eq '0.2'
      expect(purchase.tax_cost).to eq(GBP '4.00')
    end

    it 'adds taxtion as fee adjustment' do
      order.calculate_tax
      expect(order.tax_scope.count).to be > 0
    end
  end
end
