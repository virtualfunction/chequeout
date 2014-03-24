# == Addresses for users/orders
#
# Used for card billing / subscriptions etc, can belong to users, orders, etc
module Chequeout::Address
  module Addressable
    when_included do
      # Create billing_address / shipping_address methods
      Address.roles.each do |role|
        define_method '%s_address' % role do
          addresses.by_role(role).first
        end
      end
    end

    # Copy the main addresses
    def copy_addresses_from(other)
      Address.roles.each do |name|
        if addresses.by_role(name).count.zero?
          addresses << other.addresses.by_role(name).first.clone
        end
      end
    end
  end

  module ClassMethods
    # This is how we differentiate between different addresses
    def roles
      @roles ||= Set.new %w[ home work gift ]
    end

    # Do we deliver to here or is it for billing
    def purposes
      @purposes ||= Set.new %w[ billing shipping ]
    end

    # Setup the relation
    def related_to(klass)
      klass.class_eval do
        include Chequeout::Address::Addressable, Chequeout::Core::AttrScoped
        attr_scoped :altered_address
        # Setup main polymorphic association
        options = {
          dependent:  :destroy,
          as:         :addressable }
        has_many :addresses, -> { order :position }, options
        # Purpose specific actions
        Address.purposes.clone.add('').each do |purpose|
          # Purpose specification association
          details = options.merge class_name: 'Address'
          unless purpose.blank?
            related_purpose = ('%s_address' % purpose).to_sym
            has_one related_purpose, -> { where purpose: purpose }, details
            accepts_nested_attributes_for related_purpose
          end
          # Callbacks specific to purpose and action
          [ :save, :create, :update, :destroy ].each do |action|
            task = [ action, purpose, :address ].reject(&:blank?).join('_').to_sym
            register_callback_events task
          end
        end
      end
    end
  end

  when_included do
    Database.register :addressable do |table|
      table.integer     :position
      table.references  :addressable, polymorphic: true
      table.string      :postal_code, :country, :region, :locality, :street, :building, :role, :purpose, :email, :first_name, :last_name, :phone
      table.timestamps
      [ :position, :addressable_type, :addressable_id, :role, :purpose ].each do |field|
        table.index field
      end
    end

    default_scope       -> { order :position }
    scope :by_role,     -> role     { where role: role }
    scope :by_purpose,  -> purpose  { where purpose: purpose }

    belongs_to :addressable, polymorphic: true

    # Extra scopes
    purposes.each do |purpose|
      scope purpose, -> { by_purpose purpose }
    end
    roles.each do |role|
      scope role, -> { by_role role }
    end

    # This enables us to prioritize addresses
    # acts_as_list scope: [ :addressable_type, :addressable_id ]
    before_validation :ensure_contact_details
    validates :purpose, :postal_code, :country, :street, :building, :name, presence: true
    with_options allow_nil: true do |__|
      __.validates :postal_code, :country, :region, :locality, :street, :building, length: { maximum: 255 }
      __.validates :role,     inclusion: { in: roles }
      __.validates :purpose,  inclusion: { in: purposes }
    end

    # Notification / callback wrappers
    [ :save, :create, :update, :destroy ].each do |action|
      # Create create_address, create_shipping_address etc
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{action}_address_notification
          if addressable
            task = [ :#{action}, purpose, :address ].join('_').to_sym
            addressable.altered_address self do
              addressable.run_callbacks :#{action}_address do
                addressable.run_callbacks task do
                  yield
                end
              end
            end
          else
            yield
          end
        end
      METHOD
      # Register the events we created to the newly created method above
      event    = ('around_%s' % action).to_sym
      callback = ('%s_address_notification' % action).to_sym
      __send__ event, callback
    end

  end

  # Physical location
  LOCATION_FIELDS = [
    :building,
    :street,
    :locality,
    :region,
    :country,
    :postal_code
  ].freeze

  # Contact fields and name
  CONTACT_FIELDS = [
    :email,
    :phone,
    :first_name,
    :last_name,
  ].freeze

  DETAIL_FIELDS = (CONTACT_FIELDS + LOCATION_FIELDS).freeze

  def name
    [ first_name, last_name ].compact.join ' '
  end

  # Lines that make the address
  def lines
    LOCATION_FIELDS.collect { |field| __send__ field }.reject &:blank?
  end

  # Details as a hash table
  def details
    attributes.slice *DETAIL_FIELDS.collect(&:to_s)
  end

  # Copy fields from another address
  def copy_from(other)
    assign_attributes other.details
  end

  # Is this the same location?
  def same_location?(other)
    lines == other.lines
  end

  # Lines as a string of text
  def as_text
    lines.join NEWLINE
  end

  # Make sure email or phone number is entered for contact purposes
  def ensure_contact_details
    if email.blank? and phone.blank?
      message = '- please ensure you have either an email or phone contact details'
      errors.add :email, message
      errors.add :phone, message
    end
  end
end
