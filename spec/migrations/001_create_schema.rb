class CreateSchema < ActiveRecord::Migration
  def change
    with_options force: true do |database|
      database.create_table :addresses do |table|
        table.chequeout   :addressable
      end

      database.create_table :fee_adjustments do |table|
        table.chequeout   :fee_adjustments, :purchase_refundable
      end

      database.create_table :orders do |table|
        table.chequeout   :orderable, :order_tracking
      end

      database.create_table :products do |table|
        table.chequeout   :item_details, :item_tax_rates, :item_shipping_by_weight, :item_stockable
      end

      database.create_table :purchase_items do |table|
        table.chequeout   :purchase_order_lines, :purchase_inventory
      end

      database.create_table :promotions do |table|
        table.chequeout   :promotional_crtieria, :promotional_discounts, :promotional_details
      end

      database.create_table :promotion_discount_items do |table|
        table.chequeout   :promotional_discount_items
      end
    end
  end
end
