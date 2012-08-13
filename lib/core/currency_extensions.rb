module Chequeout::Core::CurrencyExtensions
  module ClassMethods
    # Use in AR classes, i.e. `Money.composition_on self, :price`
    def composition_on(model, prefix)
      fields = [ 
        [ '%s_amount'   % prefix, :cents ], 
        [ '%s_currency' % prefix, :currency_as_string ] ]
      # Construct based on AR fields
      construct = Proc.new do |cents, currency| 
        Money.new cents || 0, currency || Money.default_currency.id
      end
      # Call to_money on assignments, etc
      convert = Proc.new do |value| 
        if value.respond_to? :to_money
          value.to_money
        else
          raise ArgumentError, 'Can not convert %s to money' % value.class unless value.nil?
        end
      end
      # Set up composition fields. TODO: Deal with deprecation warning
      model.composed_of prefix, 
        :class_name   => 'Money', 
        :allow_nil    => true,
        :mapping      => fields,
        :constructor  => construct,
        :converter    => convert
    end
    
    # Setup a helper method, so one can do stuff like `GBP 4.99`
    def setup(currency)
      iso4217 = currency.to_s.upcase
      ::Kernel.__send__ :define_method, iso4217 do |amount|
        value = [ iso4217, amount ].join ' '
        Money.parse value
      end
    end
    
    # Setup curency methods for all currencies
    def setup_all_currencies
      currencies_list.keys.each do |iso|
        setup iso
      end
    end
    
    def currencies_list
      @currencies_list ||= CurrencyLoader.load_currencies rescue Money::Currency::TABLE
    end
  end
  
  module Factory
    # Handy helper method
    def amount(value)
      Money.parse '%s %s' % [ id.to_s.upcase, value ]
    end
  end
  
  when_included do
    Money::Currency.__send__ :include, Factory
    Money.setup_all_currencies
  end
end

::Money.__send__ :include, Chequeout::Core::CurrencyExtensions if defined? ::Money
