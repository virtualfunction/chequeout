require File.expand_path('../../../spec/spec_helper', __FILE__)

describe 'Event callbacks' do
  class FakeOrder < Order
  end
  
  describe Order do
    let(:order) { FakeOrder.new :status => 'basket' }
    
    it 'triggers `new_basket`' do
      # order.save
      # Assert new_basket
    end

    it 'triggers `empty_basket`' do
      # order.save
      # order.empty!
    end

    it 'triggers `delete_basket`' do
      # order.save
      # order.destroy
    end
  end

  describe PurchaseItem do
  
  end

  describe Product do
  end

end

<<-END
---
Order:
- new_basket
- empty_basket
- delete_basket
- refund_payment # Implement as a fee_adjustment
- complete_payment
- add_address
- remove_address
- summarize # For invoices, print view, pre-checkout summary
PurchaseItem:
- add_item
- remove_item
- change_quanity # Use add and remove?
Product:
- out_of_stock
- stock_refreshed
END



