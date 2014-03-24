module Chequeout::Core::CurrencyExtensions
  module ClassMethods
    # Use in AR classes, i.e. `Money.composition_on self, :price`
    def composition_on(model, prefix)
      model.class_eval <<-END
        [ :#{prefix}_amount_changed?, :#{prefix}_currency_changed? ].each do |changed|
          before_validation :clear_#{prefix}_money, if: changed
        end

        def clear_#{prefix}_money
          @#{prefix} = nil
        end

        def #{prefix}
          @#{prefix} ||= Money.new #{prefix}_amount || 0, #{prefix}_currency || Money.default_currency.id unless #{prefix}_currency.blank?
        end

        def #{prefix}=(value)
          clear_#{prefix}_money
          unless value.nil?
            raise ArgumentError, 'Can not convert %s to money' % value.class unless value.respond_to? :to_money
            money = value.to_money
            currency, cents = money.currency_as_string, money.cents
          else
            currency, cents = nil, nil
          end
          self[:#{prefix}_amount]   = cents
          self[:#{prefix}_currency] = currency
        end
      END
    end

    # Setup a helper method, so one can do stuff like `GBP 4.99`
    def setup(currency)
      iso4217 = currency.to_s.upcase
      ::Kernel.__send__ :define_method, iso4217 do |amount|
        value = [ iso4217, amount ].join ' '
        Monetize.parse value
      end
    end

    # Setup curency methods for all currencies
    def setup_all_currencies
      currencies_list.keys.each do |iso|
        setup iso
      end
    end

    def currencies_list
      @currencies_list ||= CurrencyLoader.load_currencies rescue Money::Currency.load_currencies
    end
  end

  module Factory
    # Handy helper method
    def amount(value)
      Monetize.parse '%s %s' % [ id.to_s.upcase, value ]
    end
  end

  when_included do
    Money::Currency.__send__ :include, Factory
    Money.setup_all_currencies
  end
end

::Money.__send__ :include, Chequeout::Core::CurrencyExtensions if defined? ::Money
