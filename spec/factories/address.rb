FactoryGirl.define do 
  factory :address do
    building    '6'
    street      'Warton Terrace'
    locality    'Heaton'
    region      'Tyne & Wear'
    country     'GB'
    postal_code 'NE6 5LR'
    role        'home'
    email       'test@example.com'
    phone       '123456'
    first_name  'Jason'
    last_name   'Earl'

    factory :billing_address do
      purpose   'billing'
    end

    factory :shipping_address do
      purpose   'shipping'
    end
  end
end
