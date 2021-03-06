# encoding: utf-8

# == Order - Container for purchased items
#
# Note because orders aren't always tied to a user (often many cart systems will allow one to add items
# to a cart without signing in, and even checkout in some cases anonymously, we use a session_uid field
# to track orders while in the 'basket' state. This later can be tied to a user account, or whatever is
# fit for the purpose
Chequeout.define_model :order do |item|

  item.database_strcuture do |table|
    table.timestamps
    table.text      :internal_notes, :customer_notes
    table.datetime  :payment_date
    table.string    :status, :session_uid, :total_currency
    table.decimal   :total_amount
    [ :total_amount, :status, :session_uid, :created_at, :updated_at ].each do |field|
      table.index field
    end
  end

  class << self
    # List of allow order statuses. Can be appended with Order.status_list << 'order_state'
    def status_list
      @status_list ||= %w[
        refund_requested
        part_refunded
        fully_refunded
        success
        pending
        failed
        cancelled
        refunded
        basket
      ]
    end
  end

  register_callback_events :completed_payment, :failed_payment, :refund_payment, :process_payment, :merchant_processing

  # Address and money setup, must be done prior to tax/shipping extensions
  item.model(:address).related_to self
  Money.composition_on self, :total

  with_options dependent: :destroy, inverse_of: :order do |__|
    __.has_many :purchase_items,  class_name: item.model(:purchase_item).name
    __.has_many :fee_adjustments, class_name: item.model(:fee_adjustment).name
  end

  time_convert = -> time do
    time.is_a?(Time) ? time : (Time.parse time rescue Time.now)
  end

  scope :purchased_after,     -> time { where '%s.created_at > ?' % table_name, time_convert.call(time) }
  scope :purchased_before,    -> time { where '%s.created_at < ?' % table_name, time_convert.call(time) }
  scope :by_status,           -> status { where status: status }
  scope :in_order_of_payment, -> { order payment_date: :desc }
  scope :has_item, -> item {
    distinct.
    joins(:purchase_items).
    merge item.model(:purchase_item).by_item(item)
  }

  # Might need to rethink these, and see how ActiveMerchant does things
  status_list.each do |state|
    scope state, -> { by_status state }
    register_callback_events state

    define_method '%s?' % state do
      status == state
    end

    define_method '%s!' % state do
      transaction do
        run_callbacks state do
          self.status = state
          save!
        end
      end
    end
  end

  validates :session_uid, :status, presence: true
  validates :billing_address, presence: true, associated: true, unless: :basket?
  validates :status, inclusion: { in: status_list }, allow_nil: true
  validate  :ensure_not_empty!, unless: :basket?

  attr_writer :currency

  # No money in the default order currency, used for summing caluations
  def zero
    currency.amount '0.00'
  end

  # Mark this as paid
  def paid!(time = Time.now)
    update_attribute :payment_date, time
  end

  # Has a refund of any sort been refunded?
  def refund?
    refunded? or part_refunded? or fully_refunded?
  end

  # This can be overriden such that currency can be based on address
  def currency
    @currency || detected_currency
  end

  # Fallback currency unit
  #
  # Not this must not invoke any total calulations (or you get
  # stack/recursion overflows)
  def detected_currency
    if purchase_items.empty?
      (total_currency) ? total.currency : Money.default_currency
    else
      (total_currency ? total : purchase_items.first.price).currency
    end
  end

  # Update quantities
  def update_quantities(details)
    details.each do |purchase_id, quantity|
      purchase_items.update purchase_id, quantity: quantity
    end
  end

  # This assumes this item is saved, and has an id
  def item_quantities=(table)
    update_quantities table
  end

  # Reader, just there in case view wants it
  def item_quantities
    Hash[ purchase_items.collect { |item| [ item.id, item.quantity ] } ]
  end

  # Note: If completed we really shouldn't modify order data
  def completed?
    success? or refunded?
  end

  # Added the basket? returns the item if so
  def contains(item)
    purchase_items.detect do |object|
      # We compare the fields as this saves loading the assoicated object
      item.class.base_class.name == object.brought_item_type and
      item.id == object.brought_item_id
    end
  end

  # Boolean test for item
  def has?(item)
    !! contains(item)
  end

  # Record payment date
  def payment_success!(time = Time.now)
    self.payment_date = time
    run_callbacks :completed_payment do
      success!
    end
  end

  # Wrap failure with any custom callbacks
  def payment_failed!
    run_callbacks :failed_payment do
      failed!
    end
  end

  # Process the checkout
  def checkout!
    self.total = total_price
    ok = false
    if basket? and valid? and purchase_items.count > 0
      pending!
      transaction do
        run_callbacks :process_payment do
          ok = handle_merchant_processing!
        end
      end
    end
    if ok
      payment_success!
    else
      payment_failed!
    end
  end

  # If merchant processing is needed, run callbacks and dipatch to merchant
  def handle_merchant_processing!
    skip_merchant_processing? || begin
      run_callbacks :merchant_processing do
        merchant_processing!
      end
    end
  end

  # Are the addreses the same, if set
  def shipping_same_as_billing
    billing_address.same_location? shipping_address if shipping_address and billing_address
  end

  # Assign shipping to be the billing address
  def shipping_same_as_billing=(value)
    return :skipped unless !! value and billing_address
    fields = billing_address.attributes.to_options.slice Chequeout::Address::LOCATION_FIELDS
    self.build_shipping_address unless shipping_address
    self.shipping_address.attributes = fields
  end

  # Overriden to force the procrastination of address assignment
  def attributes=(details, *args)
    is_same = details.to_options.delete :shipping_same_as_billing
    super(details, *args).tap do
      self.shipping_same_as_billing = is_same
    end
  end

  # Criteria to skip payment gateway, normally if order is zero.
  def skip_merchant_processing?
    total == zero
  end

  # Unique id for the order
  def uid
    self[:uid] ||= Digest::SHA1.hexdigest(id.to_s)[0...8]
  end

  # Sum up purchases and adjustments
  def calculated_total
    sub_total + adjustment_total
  end

  # Total of all items, excluding adjustments
  def sub_total
    sum_prices purchase_items.collect(&:total_price)
  end

  # Total of order adjustemnts such as shipping etc
  def adjustment_total
    sum_prices fee_adjustments.collect(&:price)
  end

  # Add new purchase
  def add(object, settings = Hash.new)
    details = {
      order:        self,
      brought_item: object,
      price:        (object.try(:price) || 0),
    }.merge settings.to_options
    # Only set quantity if we support it.
    scope    = purchase_items.by_item object
    purchase = scope.first || scope.build
    purchase.update! details
  end

  # Remove a purchase
  def remove(object)
    purchase_items.by_item(object).destroy_all
  end

  # Cached sum of the items, only calculating if no total set
  def total_price
    (not total or total.zero?) ? calculated_total : total
  end

  protected

  # Zero priced items might be in different currency, but inject 'zero' to avoid numeric zero
  def sum_prices(items)
    items.reject(&:zero?).push(zero).sum
  end

  # Do merchant processing, must return non false value to indicate success
  def merchant_processing!
    raise 'Merchant processing needs to be implenmenting'
  end

  # Do not let a order go through unless it's got items
  def ensure_not_empty!
    errors.add :base, basket_must_contain_items if purchase_items.empty?
  end

  # Text for empty basket error
  def basket_must_contain_items
    I18n.translate 'orders.errors.empty_basket'
  end
end
