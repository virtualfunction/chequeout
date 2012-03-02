# == Offer / Promotion Coupon Support
module Chequeout::Offer

  # == Acts as a template for a coupon.
  #
  # Coupons are basically redeemed/used instances of promotion
  # Method: discount
  module Promotional
    module ClassMethods
      # Used on a scope to see if a bunch of relevant/scoped promotions can be applied to the order
      def try_and_appy_to(order)
        find_each do |promotion|
          promotion.apply_to order
        end
      end
    end
    
    when_included do
      Database.register :promotional_discounts do |table|
        table.decimal     :discount_amount
        table.string      :discount_currency
        table.string      :discount_strategy
        table.index       :discount_amount
      end

      Database.register :promotional_details do |table|
        table.text        :terms_and_conditions, :details
        table.string      :summary
      end

      validates :summary, :discount, :presence => true
      register_callback_events :apply_to_order
      ::FeeAdjustment.related_to self
      ::Money.composition_on self, :discount
      attr_accessor :order
      attr_reader   :offer_options
      
      scope :by_discount_code, lambda { |text| 
        where :discount_code => text.to_s.strip
      }
    end
    
    # Add the coupon adjustment if we're allowed to apply it
    def apply_to(order, options = Hash.new)
      return unless applicable_for? order
      with_cart order, options do
        run_callbacks :apply_to_order do
          redeem_coupon!
        end
      end
    end
    
    # Discount code exists?
    def discount_code?
      discount_code.present?
    end
    
    # Work out discount based on strategy, default to fixed
    def calculated_discount
      code = DiscountStrategy.registry[discount_strategy.to_sym || :fixed] 
      (code) ? instance_eval(&code) : order.zero
    end

    # Create a new coupon instance, if not done already
    def redeem_coupon!
      @coupon ||= begin
        details = {
          :related_adjustment_item  => self,
          :discount_code            => discount_code,
          :display_name             => summary,
          :purpose                  => 'coupon',
          :price                    => calculated_discount * -1, # Money doesn't have negate unary method
          :order                    => order,
        }.merge coupon_details
        FeeAdjustment.create! details
      end
    end
    
    # Any other custom details to specific to the coupon
    def coupon_details
      Hash.new
    end
    
    # Is this coupon valid for a given order?
    def applicable_for?(order, options = Hash.new)
      # See if this has been redeemed as a coupon for this promotion
      return false if order_adjustments.by_order(order).count > 0 and not options[:skip_redeemed]
      # Check each of the criteria
      with_cart order, options do
        run_callbacks :order_applicable do
          :ok
        end
      end
    end

    protected
    
    # Set the basket for scope of this method
    def with_cart(basket, options = Hash.new)
      old = order
      old_options = offer_options
      self.order = basket
      @offer_options = options
      yield
    ensure
      @offer_options = old_options
      self.order = old
    end
  end
  
  # Registry to hold list of criteria items
  module Criteron
    class << self
      # Registry for criteria
      def items
        @items ||= Hash.new do |hash, key|
          hash[key] = Module.new
        end
      end
    end

    # Add all criteria to work on fee adjustments
    when_included do
      register_callback_events :order_applicable
      Chequeout::Offer::Criteron.items.values.each do |item|
        include item
      end
    end
  end
  
  DISCOUNT_SCOPES = proc do
    scope :by_discounted_item_type, lambda { |klass|
      where :discounted_item_type => klass.try(:base_class) || klass.to_s
    }
    scope :by_discounted_item, lambda { |item|
      by_discounted_item_type(item.class).where :discounted_item_id => item.id
    }
  end

  module Purchase
    when_included do
      after_destroy :check_coupons
    end
    
    def check_coupons
      order.remove_non_applicable_coupons
    end
  end

  # == Look up coupons by code for orders via virtual atttributes
  module Order
    when_included do
      attr_accessor :pending_coupon_code
      after_save    :remove_non_applicable_coupons, :apply_pending_coupon
      scope         :by_promotion, lambda { |item| joins(:fee_adjustments).merge ::FeeAdjustment.by_item(item) }
      scope         :by_promotion_id, lambda { |id| joins(:fee_adjustments).merge ::FeeAdjustment.by_item(Promotion.find(id)) }
    end
    
    # Remove any coupons that do not apply
    def remove_non_applicable_coupons
      coupons.each do |coupon|
        coupon.destroy if basket? and not coupon.related_adjustment_item.applicable_for? self, :skip_redeemed => true
      end
    end
    
    # Get fee adjustements marked as coupons
    def coupons
      fee_adjustments.coupon
    end
    
    # Get first coupon with discount code
    def coupon_code
      coupons.detect(&:discount_code?).try :discount_code
    end
    
    # Assign a coupon code to be applied
    def coupon_code=(text)
      self.pending_coupon_code = text.to_s.strip
    end
    
    # Remove coupon and offer tokens
    def remove_coupon
      coupons.select(&:discount_code?).each &:destroy
      fee_adjustments.offer_token.destroy_all
    end
    
    # Callback, applies coupon on save
    def apply_pending_coupon
      if pending_coupon_code == ''
        remove_coupon
        :coupon_removed
      elsif pending_coupon_code.present? and not coupon_code == pending_coupon_code
        promotion = Promotion.by_discount_code(pending_coupon_code).first 
        promotion.apply_to self if promotion
        :coupon_applied
      else
        :coupon_skipped
      end
    ensure
      self.pending_coupon_code = nil
    end
  end

  # == Add to FeeAdjustment if using discount code
  module DiscountCodeAdjustment
    when_included do
      scope :by_discount_code, lambda { |code| where :discount_code => code }
      Database.register :fee_adjustments do |table|
        table.string :discount_code
        table.index  :discount_code
      end
    end
  end

  # == Add to FeeAdjustment if using discounted product
  module DiscountedProductAdjustment
    when_included &DISCOUNT_SCOPES
    when_included do
      belongs_to :by_discounted_item, :polymorphic => true

      Database.register :fee_adjustments do |table|
        table.references :discounted_item, :polymorphic => true
      end
    end
  end
  
  # Define a strategy for creating discounts to orders
  def self.discount_strategy(name, &code)
    @strategy ||= Hash.new
    @strategy[name] = code
  end
  
  # Registry for different discount techniques
  class DiscountStrategy
    class << self
      
      def registry
        @registry ||= Hash.new
      end
    end

    def initialize(name, &code)
      DiscountStrategy.registry[name] = code
    end
  end
  
  # Percentage discount, like 20%
  DiscountStrategy.new :percentage do
    order.sub_total * (discount_amount / 100.0)
  end
  
  # Fixed amount in given currency
  DiscountStrategy.new :fixed do
    discount
  end
  
  # == Add new coupon criteria as methods in here
  class Criteria
    attr_reader :name, :container

    def initialize(name, &code)
      @container = Criteron.items[name]
      @name = name
      instance_eval &code
    end

    # Manual delegation (used because it's protected)
    def when_included(&code)
      container.__send__ :when_included, &code
    end

    # Manual delegation (used because it's protected)
    def define_method(name, &code)
      container.__send__ :define_method, name, &code
    end

    # Define the logic to see if promotion applies. This returns false to 
    # prevent a promotion being seen as valid, much like Rails filters and 
    # validations
    def filter(&code)
      criteria = '%s_criteria' % name
      define_method criteria, &code
      when_included { before_order_applicable criteria }
    end
    
    # Set up DB schema
    def database(action = nil, &code)
      when_included do 
        Database.register action || :promotional_crtieria, &code
      end
    end
  end
  
  Criteria.new :expiration do
    filter do
      # Use out of bound dates if not set as these will be ignored
      start   = try(:starts_at)   || Time.parse('Jan 1970')
      finish  = try(:finishes_at) || Time.parse('Jan 2050')
      date    = order.created_at
      start < date and date < finish
    end
    
    database do |table|
      table.datetime :starts_at, :finishes_at
      table.index :starts_at
      table.index :finishes_at
    end
  end
  
  Criteria.new :prevent_negative_balance do
    filter do
      (not discount) or (order.total_price - discount > order.zero)
    end
  end

  Criteria.new :disableable do
    filter { not disabled? }
    database do |table|
      table.boolean :disabled, :default => false, :null => false
      table.index   :disabled
    end
  end

  Criteria.new :product_specific do 
    filter do 
      order.has? discounted_item and not product_specific_coupon_used? if order and try :discounted_item
    end
    
    define_method :product_specific_coupon_used? do
      order.coupons.by_discounted_item(discounted_item).count > 0
    end
    
    when_included &DISCOUNT_SCOPES
    when_included do
      belongs_to :discounted_item, :polymorphic => true
    end
    
    database do |table|
      table.references  :discounted_item, :polymorphic => true
    end
  end
  
  Criteria.new :discount_code do 
    filter do 
      offer_options[:skip_redeemed] or ((applies_with_coupon_code? or applies_with_offer_token?) and not applied_alredy?)
    end
    
    # Check with offer token (FeeAdjustment)
    define_method :applies_with_offer_token? do
      offer_tokens.by_discount_code(discount_code).count > 0 unless try(:discount_code).blank?
    end
    
    # See if this has been entered using the order virtual accessor
    define_method :applies_with_coupon_code? do
      order.pending_coupon_code == discount_code
    end
    
    # Scan for matching codes
    define_method :applied_alredy? do
      order.coupons.any? { |item| item.discount_code == discount_code }
    end
    
    # Offer tokens are fee adjustments that simply hold the coupon code
    define_method :offer_tokens do 
      order.fee_adjustments.offer_token
    end
    
    database do |table|
      table.string :discount_code
      table.index  :discount_code
    end
    
    when_included do
      scope :by_discount_code, lambda { |code| where :discount_code => code }
    end
  end
end

