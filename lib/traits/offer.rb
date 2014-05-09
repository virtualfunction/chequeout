# == Offer / Promotion Coupon Support
Chequeout.define_feature :offer do |feature|

  # == Acts as a template for a coupon.
  #
  # Coupons are basically redeemed/used instances of promotion
  # Method: discount
  feature.behaviour_for :promotion do |item|
    item.database_strcuture do |table|
      # Discounts
      table.decimal     :discount_amount
      table.string      :discount_currency, :discount_strategy
      table.index       :discount_amount
      # Details
      table.text        :terms_and_conditions, :details
      table.string      :summary
    end

    class << self
      # Used on a scope to see if a bunch of relevant/scoped promotions can be applied to the order
      def try_and_appy_to(order)
        find_each do |promotion|
          promotion.apply_to order
        end
      end

      # Override this for other ways look up promo codes
      def using_code(text)
        by_discount_code(text).to_a
      end
    end

    validates :summary, :discount, presence: true
    register_callback_events :apply_to_order, :order_applicable
    context.model(:fee_adjustment).related_to self
    ::Money.composition_on self, :discount
    attr_accessor :order
    attr_reader   :offer_options

    scope :by_discount_code, -> text {
      where discount_code: text.to_s.strip
    }

    # Add the coupon adjustment if we're allowed to apply it
    def apply_to(order, options = Hash.new)
      return unless applicable_for? order
      with_cart order, options do
        run_callbacks :apply_to_order do
          redeem_coupon!
        end
      end
    end

    # Percentage discount, like 20%
    def percentage_discount
      order.sub_total * (discount_amount / 100.0)
    end

    # Fixed amount in given currency
    def fixed_discount
      discount
    end

    # Discount code exists?
    def discount_code?
      discount_code.present?
    end

    # Work out discount based on strategy, default to fixed
    def calculated_discount
      action = '%s_discount' % discount_strategy
      (respond_to? action) ? __send__(action) : order.zero
    end

    # Create a new coupon instance, if not done already
    def redeem_coupon!
      @coupon ||= begin
        details = {
          related_adjustment_item:  self,
          discount_code:            order.pending_coupon_code,
          display_name:             summary,
          purpose:                  'coupon',
          price:                    calculated_discount * -1, # Money doesn't have negate unary method
          order:                    order,
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
      return false if (order_adjustments.by_order(order).count > 0 and not options[:skip_redeemed]) or frozen?
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

  # Ensure related coupons get removed when removing a purchase
  feature.behaviour_for :purchase_item do |item|
    after_destroy :check_coupons

    def check_coupons
      order.remove_non_applicable_coupons
    end
  end

  # Promotions can have multiple items, so this acts as a join relation
  feature.behaviour_for :promotion_discount_item do |item|
    item.database_strcuture do |table|
      table.belongs_to  :promotion
      table.belongs_to  :discounted, polymorphic: true
    end

    belongs_to :promotion
    belongs_to :discounted, polymorphic: true

    validates :promotion, :discounted, presence: true
    # Make sure this is unique for both items
    validates_relations_polymorphic_uniqueness_of :discounted, :promotion

    scope :by_discounted_type, -> klass {
      where discounted_type: klass.try(:base_class) || klass.to_s
    }
    scope :by_discounted, -> item {
      by_discounted_type(item.class).where discounted_id: item.id
    }
  end

  # == Look up coupons by code for orders via virtual atttributes
  feature.behaviour_for :order do |item|
    attr_accessor :pending_coupon_code
    after_save    :remove_non_applicable_coupons, :apply_pending_coupon
    scope         :by_promotion,    -> item { joins(:fee_adjustments).merge ::FeeAdjustment.by_item(item) }
    scope         :by_promotion_id, -> id   { joins(:fee_adjustments).merge ::FeeAdjustment.by_item(Promotion.find(id)) }

    # Remove any coupons for basket if the promotion no longer applies (ignoring if it's been redeemed prior)
    def remove_non_applicable_coupons
      coupons.each do |coupon|
        promotion = coupon.related_adjustment_item
        applicable = promotion.applicable_for? self, skip_redeemed: true if promotion
        coupon.destroy if basket? and not applicable
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
        self.class.context.model(:promotion).using_code(pending_coupon_code).any? do |promotion|
          promotion.apply_to self
        end
        :coupon_applied
      else
        :coupon_skipped
      end
    ensure
      self.pending_coupon_code = nil
    end
  end

  # == Add to FeeAdjustment if using discount code
  feature.behaviour_for :fee_adjustment do |item|
    item.database_strcuture do |table|
      table.belongs_to :discounted_item, polymorphic: true
      table.string :discount_code
      table.index  :discount_code
    end

    scope :by_discount_code, -> code { where discount_code: code }
    scope :by_discounted_item_type, -> klass {
      where discounted_item_type: klass.try(:base_class) || klass.to_s
    }
    scope :by_discounted_item, -> item {
      by_discounted_item_type(item.class).where discounted_item_id: item.id
    }
  end

  # ---[ OFFER TYPES ]---

  feature.behaviour_for :promotion, trait: :expiration do |item|
    item.database_strcuture do |table|
      table.datetime :starts_at, :finishes_at
      table.index :starts_at
      table.index :finishes_at
    end

    before_order_applicable :check_expiration

    def check_expiration
      # Use out of bound dates if not set as these will be ignored
      start   = try(:starts_at)   || Time.parse('Jan 1970')
      finish  = try(:finishes_at) || Time.parse('Jan 2050')
      date    = order.created_at
      start < date and date < finish
    end
  end

  feature.behaviour_for :promotion, trait: :prevent_negative_balance do |item|
    before_order_applicable :check_for_negative_balance

    def check_for_negative_balance
      offer_options[:skip_redeemed] or (not discount) or (order.total_price - discount >= order.zero)
    end
  end

  feature.behaviour_for :promotion, trait: :disableable do |item|
    item.database_strcuture do |table|
      table.boolean :disabled, default: false, null: false
      table.index   :disabled
    end

    before_order_applicable :check_disableable

    def check_disableable
      not disabled?
    end
  end

  feature.behaviour_for :promotion, trait: :item_specific do |item|
    # TODO: Table def's for promotion_discount_items

    before_order_applicable :check_discount_items
    has_many :promotion_discount_items, dependent: :destroy, inverse_of: :promotion

    def check_discount_items
      discounted = discounted_items
      # Set insection order purchases and promotion discount items
      products = discounted.select do |item|
        order.has? item
      end
      # Promotion is valid if no products have any coupon used (or no products)
      valid = products.all? do |product|
        order.coupons.by_discounted_item(product).count.zero?
      end
      valid and not products.size.zero? unless discounted.size.zero?
    end

    def discounted_items
      promotion_discount_items.collect &:discounted
    end
  end

  feature.behaviour_for :promotion, trait: :discount_code do |item|
    item.database_strcuture do |table|
      table.string :discount_code
      table.index  :discount_code
    end

    before_order_applicable :check_discount_code
    scope :by_discount_code, -> code { where discount_code: code }

    def check_discount_code
      offer_options[:skip_redeemed] or ((applies_with_coupon_code? or applies_with_offer_token?) and not applied_alredy?)
    end

    # Check with offer token (FeeAdjustment)
    def applies_with_offer_token?
      offer_tokens.by_discount_code(discount_code).count > 0 unless try(:discount_code).blank?
    end

    # See if this has been entered using the order virtual accessor
    def applies_with_coupon_code?
      order.pending_coupon_code == discount_code
    end

    # Scan for matching codes
    def applied_alredy?
      order.coupons.any? { |item| item.discount_code == discount_code }
    end

    # Offer tokens are fee adjustments that simply hold the coupon code
    def offer_tokens
      order.fee_adjustments.offer_token
    end
  end
end
