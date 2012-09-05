# == Shipping
#
# This works much like taxation, in the sense it uses adjustments, and hooks 
# into the address events to determin the shipping costs.
#
# A very basic implementation, Shipping::CalculateByWeight is included to provide
# an example of how to calculate shipping price based on the weight of the 
# purchased products. Generally one should be able to just modify 
# the Shipping::CalculateByWeight#shipping_weight_price method. For more advanced
# setups this method would probably need to consider different types of shipping, 
# along with other shipping extras (e.g. insurance, surface mail, airmail etc)
#
# The weight of products for shipping is totally arbitary (not tied to being a 
# specific units, but one treat this in a consistent manner. I would say it's 
# safest to use a metric unit that can be represented as an integer such as 
# grams).
#
# The Shipping::Order#calculate_shipping_cost method is used to abstractly 
# work out the shipping cost. This is done in such a manner so one can use a 
# mixture of shipping price rules. (i.e. products with prices based on weight, 
# quantity, fixed price etc). Hence the abstract version returns Order#zero but
# implementations delegate to specific versions + call super to trigger other 
# implementations in the dispatch chain.
module Chequeout::Shipping

  # == Order shipping details
  # Note, addresses must be associated to orders prior to including
  module Order
    when_included do
      after_save_shipping_address     :calculate_shipping
      after_destroy_shipping_address  :calculate_shipping
      register_callback_events        :shipping_updated
      validates   :shipping_address, :associated => true
    end
    
    # Base case, overidden versions of this call super
    def calculate_shipping_cost
      zero
    end
    
    # Create or update the total shipping
    def calculate_shipping
      return :skipped unless basket?
      run_callbacks :shipping_updated do
        shipping_item.update_attributes! \
          :display_name => shipping_display_name,
          :price        => calculate_shipping_cost
      end
    end

    # Translate the what the shipping comes up on the invoice
    def shipping_display_name
      I18n.translate 'orders.shipping.item_name'
    end
        
    # Assuming there is one main shipping item, this will find or build it
    def shipping_item
      shipping_scope.first || shipping_scope.build(shipping_options)
    end
    
    # Shipping specific options, used on creation 
    def shipping_options
      Hash.new
    end
    
    # Adjustments specific to shipping 
    def shipping_scope
      fee_adjustments.shipping
    end
    
    # pre-calculated shipping total
    def shipping_total
      shipping_scope.collect(&:price).push(zero).sum
    end
  end
  
  # == Dispatchable Order
  # Field: tracking_code, dispatch_date
  module DispatchableOrder
    when_included do
      scope :dispatched, -> state = true { where 'dispatch_date IS %s NULL' % ('NOT' if state) }
      attr_accessor :dispatch_pending
      register_callback_events :dispatched
      before_save :trigger_dispatch_if_required
      Database.register :order_tracking do |table|
        table.datetime  :dispatch_date
        table.index     :dispatch_date
      end
    end
    
    # Dispatched, based on dispatch date being present
    def dispatched?
      not dispatch_date.nil?
    end

    # Aliased for form views
    def dispatched
      dispatched?
    end
    
    # Callback: Trigger a dispatch event
    def trigger_dispatch_if_required
      return :ok if dispatch_pending.nil? or dispatch_pending == dispatched? 
      if dispatch_pending
        run_callbacks :dispatched do
          self.dispatch_date = Time.now
          self.dispatch_pending = nil
        end
      else
        self.dispatch_date = nil
      end
    end
    
    # Mark as dispatched now
    def dispatched!
      update_attributes :dispatched => true
    end
    
    # Dispatched, true or false (can cast from string)
    def dispatched=(state)
      self.dispatch_pending = not([ '', '0', 'false' ].include? state.to_s.strip)
    end
  end
  
  # == Trackable Order
  # Field: tracking_code
  module TrackableOrder
    when_included do
      scope :by_tracking_code, -> code { where :tracking_code => tracking_code }
      include Chequeout::Shipping::Order
      include Chequeout::Shipping::DispatchableOrder
      Database.register :order_tracking do |table|
        table.string    :tracking_code
        table.index     :tracking_code
      end
    end

    # Use this to add a tracking code. 
    def dispatch_with_tracking!(tracking_code = nil, date = Time.now)
      update_attributes! \
        :tracking_code  => tracking_code, 
        :dispatch_date  => date, 
        :dispatched     => not(date.nil?)
    end
  end
  
  # == Add to Product
  # Field: weight (in grams), use_weight_for_shipping (or method '?')
  module Item
    when_included do
      Database.register :item_shipping_by_weight do |table|
        table.boolean   :use_weight_for_shipping, :default => true, :null => true
        table.integer   :weight
      end
    end

    # If an item has a weight
    def has_shipping_weight?
      weight and use_weight_for_shipping?
    end
  end
  
  # == For products that have fixed shipping costs
  module CalculateByFixedCost
    module Item
      when_included do
        Database.register :item_shipping_cost do |table|
          table.integer   :shipping_price_amount
          table.string    :shipping_price_currency
        end

        Money.composition_on self, :shipping_price
      end
    end

    # Get the shipping costs by weight and call any other methods in the dispatch chain
    def calculate_shipping_cost
      super + shipping_cost_based_on_fixed_cost
    end

    def shipping_cost_based_on_fixed_cost
      purchase_items.inject zero do |sum, purchase|
        item = purchase.brought_item
        sum += item.shipping_price * purchase.quantity if item.respond_to? :shipping_price and item.shipping_price
        sum
      end
    end
  end

  # == Work out shipping price based on aggregate order weight
  # If a purchased item is marked to alter shipping based on weight it will 
  # modify the order based on this.
  module CalculateByWeight
    # Get the shipping costs by weight and call any other methods in the dispatch chain
    def calculate_shipping_cost
      super + shipping_cost_based_on_weight
    end
    
    # Sum up the total of all items that weight something
    def total_weight
      purchase_items.inject 0 do |sum, purchase|
        item = purchase.brought_item
        sum += item.weight * purchase.quantity if item.try :has_shipping_weight?
        sum
      end
    end
    
    # Shipping costs by weight
    def shipping_cost_based_on_weight
      shipping_weight_price total_weight
    end
    
    # Basic shipping weight converter. This could be replaced with logic to 
    # look up the price in the DB based on desired service
    def shipping_weight_price(weight)
      cost = case weight
        when 0     ... 100    then '0.29'
        when 100   ... 500    then '2.60'
        when 500   ... 2000   then '4.99'
        when 20000 ... 50000  then '8.99'
        else '29.99'
      end
      currency.amount cost
    end
  end
end
