# == Used to model adjustments made by shipping, tax etc
#
# This acts much like a brought item on the invoice
module Chequeout::FeeAdjustment
  module ClassMethods
    # Different reasons / purposes for the adjustment
    def purposes
      @purposes ||= Set.new %w[
        tax
        shipping
        offer_token
        manual_alteration
        coupon
        discount
        layaway_payment
        refund
      ]
    end

    # Set up associations
    def related_to(klass)
      klass.class_eval do
        has_many :order_adjustments,
          class_name: 'FeeAdjustment',
          as:         :related_adjustment_item,
          dependent:  :nullify
      end
    end
  end

  when_included do
    Database.register :fee_adjustments do |table|
      table.belongs_to  :order
      table.references  :related_adjustment_item, polymorphic: true
      table.string      :purpose, :display_name, :price_currency
      table.integer     :price_amount
      table.datetime    :created_at, :processed_date
      [ :purpose, :order_id, :price_amount, :related_adjustment_item_type, :related_adjustment_item_id ].each do |field|
        table.index field
      end
    end

    # Coupon, or other item related to this adjusmtent
    belongs_to :related_adjustment_item, polymorphic: true
    belongs_to :order
    Money.composition_on self, :price
    before_validation :infer_order

    scope :by_item_type, -> klass {
      name = (klass.respond_to? :base_class) ? klass.base_class : klass.to_s
      where related_adjustment_item_type: name
    }
    scope :by_item, -> item {
      by_item_type(item.class).where related_adjustment_item_id: item.id
    }

    scope :by_purpose,    -> purpose { where purpose: purpose }
    scope :by_order,      -> order   { where order_id: order.id }

    # Create purpose specific scopes
    purposes.each do |item|
      scope item, -> { by_purpose item }

      define_method '%s?' % item do
        purpose == item
      end
      define_method '%s!' % item do
        self.purpose = item
        save!
      end
    end

    validates :purpose, inclusion:  { in: purposes }, allow_nil:  true
    validates :purpose, :price, :display_name, :order, presence: true

    # attr_protected :price # We can probably ignore this as this is only normally exposed by admin controllers
  end

  # Try and work order if not explicitly set
  def infer_order
    self.order ||= related_adjustment_item.try :order
  end

  # Only these should be mutable. If shipping, tax, etc are needing to be
  # mutable it is better to override this method or add adjustments as a
  # manual alteration
  def mutable?
    manual_alteration? or discount?
  end
end
