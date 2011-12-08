class Promotion < ActiveRecord::Base
  __ = Chequeout::Offer
  include __::Promotional
  include __::Criteron
  validates :details, :presence => true
end
