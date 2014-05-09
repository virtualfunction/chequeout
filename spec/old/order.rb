class Order < ActiveRecord::Base
  include Chequeout::Order
  include Chequeout::Offer::Order
  include Chequeout::Shipping::TrackableOrder
  include Chequeout::Shipping::CalculateByWeight
  include Chequeout::Taxation::Order
  include Chequeout::Refundable::Order

  Address.purposes.each do |purpose|
    accepts_nested_attributes_for "#{purpose}_address".to_sym
  end
end
