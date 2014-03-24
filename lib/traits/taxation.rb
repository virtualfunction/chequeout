# == Don't you just love the feckin' government? The Bastards!
#
# Taxation generally works by modifying the order with an adjustment. Because
# (sales) tax is normally based on geographic location, product tax
# band/percentage, this will hook into the address modification events.
#
# Products can hold information regarding their tax rate/band through a tax_rate
# field. Taxation::Item can be included to register the DB fields for this.
#
# Each purchase will use the tax_rate information for the product to calculate
# the tax cost for each item pruchased. Order lines / purcahases need to include
# Taxtion::Purchase for this to happen
#
# Orders will need to include Taxation::Order. This will use calculate_tax_cost
# to sum up the tax from each purchase.
module Chequeout::Taxation

  # == Product / Brought Item taxation specific
  # Adds tax_rate field to products. Taxation::Purchase does the caluations
  module Item
    when_included do
      Database.register :item_tax_rates do |table|
        table.decimal :tax_rate
      end
    end
  end

  # == Taxation in individual purchases
  # Typically the default behaviour here is to look at the brought item / product
  # to see what tax_rate it falls into. The tax_cost method will return the cost
  # based on the item price/tax_rate/quantity
  module Purchase
    # Calculates the amount of tax for this purchased product
    def tax_cost
      total_price * tax_rate
    end

    # This will calculate the rate of tax as a 0..1 fraction/percentage for the
    # item(s) purchased. By default this is assuming this is in the item, but
    # one can modify this if tax_rate is based on bands
    def tax_rate
      brought_item.try(:tax_rate) || 0
    end
  end

  # == Taxation on an Order
  # Note: Addresses must be related to an order prior to including
  module Order
    when_included do
      after_save_address        :calculate_tax
      after_destroy_address     :calculate_tax
      register_callback_events  :taxation_updated
    end

    # Adjustments for tax
    def tax_scope
      fee_adjustments.tax
    end

    # Get the first saved tax item or create a new tax adjustment
    def tax_item
      tax_scope.first || tax_scope.build(tax_options)
    end

    # Any special options for tax can go here
    def tax_options
      Hash.new
    end

    # Calculate tax if this is still a cart basket
    def calculate_tax
      return :skipped if purchase_items.empty? or not basket?
      run_callbacks :taxation_updated do
        tax_item.update \
          display_name: taxation_display_name,
          price:        calculate_tax_cost
      end
    end

    # translation for tax items
    def taxation_display_name
      I18n.translate 'orders.taxation.item_name'
    end

    # Works out tax cost by summing up tax for all purchases
    def calculate_tax_cost
      purchase_items.inject zero do |total, purchase|
        total += purchase.try(:tax_cost) || zero
      end
    end
  end
end
