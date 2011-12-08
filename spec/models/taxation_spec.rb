require File.expand_path('../../../spec/spec_helper', __FILE__)

Tax = Chequeout::Taxation

describe Tax do 
  # TODO: Test event hooks?

  specify { Order.should be < Tax::Order }
  specify { PurchaseItem.should be < Tax::Purchase }
  specify { Product.should be < Tax::Item }
  
  describe 'calcuations' do
    let(:order) { FactoryGirl.create :filled_basket_order }
    
    it 'perform basic calculations' do
      order.calculate_tax_cost.should == GBP('4.00')
    end
    
    it 'integrates with purchased items' do
      purchase = order.purchase_items.first
      purchase.tax_rate.to_s.should == '0.2'
      purchase.tax_cost.should == GBP('4.00')
    end
    
    it 'adds taxtion as fee adjustment' do
      order.calculate_tax
      order.tax_scope.count.should > 0
    end
  end
end
