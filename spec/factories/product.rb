FactoryGirl.define do
  factory :product do
    use_weight_for_shipping true
    weight                  454
    stock_levels            3
    display_name            'Test product'
    price                   { GBP '9.99' }
    tax_rate                '0.2'.to_d 
  end
end
