# == A product that can be purchased
module Chequeout::Product
  when_included do
    Database.register :item_details do |table|
      table.text    :description
      table.string  :display_name, :price_currency
      table.integer :price_amount
      table.index   :price_amount
      table.timestamps
    end

    validates :price, :display_name, presence: true

    # Money.composition_on self, :price
    ::PurchaseItem.related_to self
  end
end
