# == A product that can be purchased
Chequeout.define_model :product do |item|
  item.database_strcuture do |table|
    table.text    :description
    table.string  :display_name, :price_currency
    table.integer :price_amount
    table.index   :price_amount
    table.timestamps
  end

  validates :price, :display_name, presence: true

  Money.composition_on self, :price if table_exists? and 'price_currency'.in? column_names
  setup do
    context.model(:purchase_item).related_to self
  end
end
