FactoryGirl.define do
  factory :promotion do
    disabled          false
    starts_at         Time.parse('January 2010')
    finishes_at       Time.parse('January 2020')
    discount          { GBP '1.99' }
    discount_strategy 'fixed'
    summary           'A basic GBP 1.99 discount'
    details           'Wow, what an amazing discount'
  end
end
