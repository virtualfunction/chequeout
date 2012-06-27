# == Purchased Item
#
# Links a sheet, track or album to an order
#
# Purchaseable items (i.e. that implement PurchaseItem::SafeGuard) must respond to:
# * display_name
# * price
module Chequeout::PurchaseItem
  # This doubles up in places as a type-safety check
  module SafeGuard
    # If someone has purchased the item, we should block it's destruction as a
    # a rule of thumb
    def destructable?
      purchases.count.zero?
    end
  end
  
  module ClassMethods
    # Called by models related to this by association
    def related_to(klass)
      klass.class_eval do
        has_many :purchases, 
          :dependent  => :destroy, 
          :class_name => 'PurchaseItem', 
          :as         => :brought_item
        scope :has_purchases, joins(:purchases)
        # Protect brought items - TODO, do we need this, we copy the 
        # display_name + price into the purchase
        before_destroy :destructable?
        include Chequeout::PurchaseItem::SafeGuard
      end
      # Create back association
      items_name = klass.name.underscore.pluralize.to_sym
      scope items_name, by_item_type(klass)
      ::Order.class_eval do
        has_many items_name, 
          :through      => :purchases, 
          :source       => :brought_item, 
          :source_type  => klass.name
      end
    end
  end

  when_included do
    Database.register :purchase_order_lines do |table|
      table.references  :brought_item, :polymorphic => true
      table.belongs_to  :order
      table.integer     :price_amount
      table.string      :price_currency, :display_name
      table.timestamps
      [  :brought_item_type, :brought_item_id, :order_id, :price_amount ].each do |field|
        table.index field
      end
    end

    # Wrap with custom basket callbacks, this must be done before anything else to 
    # preserve the callback dispatch order
    [ :create, :update, :destroy ].each do |action|
      class_eval <<-CODE
        def #{action}(*args)
          (order.try :basket?) ? run_callbacks(:basket_modify) { super } : super
        end
      CODE
    end

    register_callback_events :basket_modify
    Money.composition_on self, :price
    
    belongs_to  :order
    belongs_to  :brought_item, :polymorphic => true

    # By item
    scope :by_item_type, lambda { |klass|
      name = (klass.respond_to? :base_class) ? klass.base_class : klass.to_s
      where :brought_item_type => name
    }
    scope :by_item, lambda { |item|
      by_item_type(item.class).where :brought_item_id => item.id
    }
    # By order
    scope :by_order, lambda { |item|
      where :order_id => item.id
    }
    
    validates :brought_item, :order, :presence => true
    validate  :test_item_type
    
    before_validation :unit_price
    # Validate price?
    
    attr_protected :price
    attr_accessor :force_copy_details
    
    # Don't duplicate an item
    validates_relations_polymorphic_uniqueness_of :brought_item, :order    
  end
  
  # Only allow related types to be assigned
  def test_item_type
    klass = brought_item_type.constantize rescue nil
    errors.add :brought_item_type, 'bad type found' if klass and Chequeout::PurchaseItem::SafeGuard < klass
  end
  
  # Copy price from item, assuming it has a purchase price
  def unit_price
    copy_details if price_amount.nil? or order.try :basket? or force_copy_details
    price
  end
  
  # Copy details from original product
  def copy_details
    return if frozen? # Items marked for removal should be skipped
    self.force_copy_details = false
    self.price        = brought_item.try :price
    self.display_name = brought_item.try :display_name
  end
  
  # Price based on quantity
  def total_price
    unit_price * quantity
  end
end
