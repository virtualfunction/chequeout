# == Allows the tracking of sotck for purchasable items
module Chequeout::Inventory

  # == Product Inventory Management
  # Adds a stock_levels field to track stock levels
  # If stock_levels is set to nil, the product will not have inventory tracking
  # Creates model callbacks: out_of_stock, stock_replenished
  module ItemManagement
    when_included do
      Database.register :item_stockable do |table|
        table.integer :stock_levels
        table.index   :stock_levels
      end
      register_callback_events :stock_replenished, :out_of_stock
      scope :out_of_stock,  -> { where 'stock_levels <= 0' }
      scope :in_stock,      -> { where 'stock_levels > 0' }
    end

    # See if a product has the number of items avaliable to purchase
    def has_inventory?(amount)
      not(tracking_inventory?) or stock_levels > amount or stock_levels.nil?
    end

    # Are we able to track inventory levels for this product
    def tracking_inventory?
      respond_to?(:stock_levels) and not(stock_levels.nil?)
    end

    # Is this item in stock
    def in_stock?
      has_inventory? 1
    end

    # Is this item out of stock
    def out_of_stock?
      not in_stock?
    end

    # Reduce inventory levels
    def decrease_inventory!(amount = 1)
      change_inventory_by -amount
    end

    # Increase inventory levels
    def increase_inventory!(amount = 1)
      change_inventory_by amount
    end

    # Change inventory by specific level, and save
    def change_inventory_by(amount)
      return unless tracking_inventory?
      set_inventory stock_levels + amount
      save!
    end

    # Overrides attribute writer and wraps set_inventory
    def stock_levels=(level)
      set_inventory level
    end

    # Change the levels of investory by a specific amount
    def set_inventory(level)
      new_level = level.to_i unless level.blank?
      old_level = stock_levels.to_i
      change_levels = -> { self[:stock_levels] = new_level }
      if tracking_inventory? and old_level <= 0 and (new_level.nil? or new_level > 0)
        # Got more stock :)
        run_callbacks :stock_replenished, &change_levels
      elsif tracking_inventory? and new_level <= 0
        # Out of stock
        run_callbacks :out_of_stock, &change_levels
      else
        # Otherwise just change
        change_levels.call
      end
    end
  end

  module FeeAdjustment
    when_included do
      Database.register :purchase_refundable do |table|
        table.integer :quantity
      end
    end
  end

  # == Add to purchase items to ensure inventory rules are applied
  module Purchaseable
    when_included do
      Database.register :purchase_inventory do |table|
        table.integer :quantity
      end
      before_save :update_inventory
      before_destroy :restock_items
      validates :quantity, numericality: { only_integer: true }
      after_save :remove_zero_quantity_items, :reset_old_quantity # Note a `before` callback will cause errors
      after_destroy :reset_old_quantity
      attr_reader :old_quantity
    end

    # Used because on destroy the quantity_modified is probably 0
    def restock_items
      brought_item.try :change_inventory_by, quantity
    end

    # Items with 0 quantity shouldn't be saved to the basket
    def remove_zero_quantity_items
      return :ok if quantity > 0 or not(order.try :basket?)
      destroy
      false
    end

    # After save/construct/find, we can reset old quanity tracking
    def reset_old_quantity
      @old_quantity = nil
    end

    def set_quantity
      quantity
    end

    # This must be used to invoke inventory changes
    def set_quantity=(amount)
      @old_quantity = quantity || 0 unless old_quantity
      self.quantity = amount
    end

    # Changed number of items purchased
    def quantity_modified
      return 0 unless old_quantity and quantity
      quantity - old_quantity
    end

    # Callback
    def update_inventory
      return if quantity_modified.zero? or not(order.try :basket?)
      brought_item.try :change_inventory_by, -quantity_modified
    end
  end
end
