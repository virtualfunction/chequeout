# == Refunds
#
# Refunds are modelled as amendments made via the fee_adjustments. If a 
# transaction has a refund, then it will be added as an adjustment. This is done
# so that multiple refunds can be made without altering the order history. 
module Chequeout::Refundable    
  module Purchase
    when_included do
      register_callback_events :refund_purchase
    end
    
    # Has this been refunded, either fully or partially?
    def refunded?
      refund_items.count > 0
    end
    
    # Collection of existing refund adjustments
    def refund_items
      FeeAdjustment.refund.by_item self
    end
    
    # Number of items that have been refunded to date
    def refunded_quantity
      refund_items.collect(&:quantity).sum
    end
    
    # Mark this purchased item as refunded. 
    # 
    # Note: This will not do anything with the payment gateway. A block may get 
    # passed which may make a call to the payment gateway to do the refund
    #
    # settings can be: 
    # * amount (Money)
    # * quantity (defaults to all items)
    # * processed (Date or true)
    def refund!(settings = Hash.new)
      return false if order.fully_refunded?
      transaction do
        run_callbacks :refund_purchase do
          # Mark order as part refunded
          order.update_attribute :status, 'part_refunded'
          # Use todays date if we pass set processed to true
          date    = settings[:processed] if settings[:processed].is_a? Time
          date    = Time.now if true == date
          # Use specificed quantity, or work out based on non refunded items to date
          count   = settings[:quantity] || (quantity - refunded_quantity)
          # Work out how much we need to refund if no amount given
          amount  = (settings[:amount] || (unit_price * count)) * -1
          # Record refund as an adjustment
          refund  = order.fee_adjustments.refund.create! \
            :related_adjustment_item => self,
            :display_name   => settings[:display_name] || I18n.translate('orders.refund.purchase', :item => display_name),
            :quantity       => count,
            :price          => amount,
            :processed_date => nil
          # Pass back refund to optional block
          result = yield refund if block_given?
          # Mark as processed if required
          refund.update_attribute :processed_date, date unless false == result
          refund
        end
      end
    end
  end
  
  module Order
    when_included do
      register_callback_events :refund_payment
    end

    # Do a full refund, boolean indicates if this has been processed or pending
    # This will individiually make the refunds for each purchased item.
    def full_refund!(settings = Hash.new)
      return false if fully_refunded?
      date = settings[:processed_date]
      date = Time.now if true == date
      transaction do
        run_callbacks :refund_payment do
          # Refund each item
          refunds = purchase_items.collect &:refund!
          # Call back
          result  = yield order if block_given?
          # If OK, mark items as processed if needed and mark order as refunded
          unless false == result 
            refunds.each do |refund|
              refund.update_attribute :processed_date, date if date
            end
            update_attribute :status, 'fully_refunded'
            refunds
          end
        end
      end
    end
    
    # Mark an order as generally refunded (useful for refunding ad-hoc amounts
    # of cash. Pass a block should this need to be processed by the merchant, 
    # or any other custom actions need to be done 
    def general_refund!(settings = Hash.new)
      total   = calculated_total
      date    = settings[:processed_date]
      date    = Time.now if true == date
      message = settings[:display_name] || I18n.translate('orders.refund.order', :order => uid)
      amount  = settings[:amount]       || total_price
      amount  = order.currency.amount amount unless amount.is_a? Money
      state   = (amount < total) ? 'part_refunded' : 'fully_refunded'
      state   = settings[:state] || state
      return false if fully_refunded? or amount.cents.zero?
      transaction do
        run_callbacks :refund_payment do
         # Record this refund as an ad-hoc refund adjustment
          refund = fee_adjustments.refund.create! \
            :display_name => message,
            :price        => amount * -1
          result = yield order if block_given?
          # If OK, mark as refunded
          unless false == result 
            refund.update_attribute :processed_date, date if date
            update_attribute :status, state
            refund
          end
        end
      end
    end
  end
end
