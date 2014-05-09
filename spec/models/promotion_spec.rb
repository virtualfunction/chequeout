require 'spec_helper'

# Offer = Chequeout::Offer

describe Promotion do

  [ Order, Product, Promotion ].each &:destroy_all
  let(:order) { FactoryGirl.create :filled_basket_order }
  let(:promotion) { FactoryGirl.create :promotion }

  specify { expect(Promotion.features).to include(:offer) }
  specify { expect(FeeAdjustment.features).to include(:offer) }
  specify { expect(PromotionDiscountItem.features).to include(:offer) }

  describe 'offer discount' do
    let(:coupons) { order.fee_adjustments.coupon }
    describe 'fixed' do
      before do
        promotion.apply_to order
      end

      it 'should alter the total' do
        expect(coupons.count).to eq 1
        expect(coupons.first.price).to eq GBP('-1.99')
      end
    end

    describe 'percentage - 20%' do
      before do
        promotion.update discount_strategy: 'percentage', discount_amount: 20
        promotion.apply_to order
      end

      it 'should alter the total' do
        expect(coupons.count).to eq 1
        expect(coupons.first.price).to eq GBP('-4.00')
      end
    end
  end

  describe 'offer criteria' do
    shared_examples 'does not apply to order' do
      it 'is rejected' do
        expect(promotion.applicable_for? order).to be false
      end
    end

    shared_examples 'applies to order' do
      it 'is accepted' do
        expect(promotion.applicable_for? order).to be :ok
      end
    end

    describe 'expiry' do
      before do
        promotion.starts_at   = 1.year.ago
        promotion.finishes_at = 1.year.since
      end
      include_examples 'applies to order'

      describe 'expired' do
        before { promotion.finishes_at = 1.year.ago }
        include_examples 'does not apply to order'
      end
    end

    describe 'disablable' do
      before { promotion.disabled = true }
      include_examples 'does not apply to order'
    end

    describe 'product specific' do
      let(:discounted) { FactoryGirl.create :product, display_name: 'Another item' }

      before do
        promotion.promotion_discount_items.create! discounted: discounted
      end

      include_examples 'does not apply to order'

      describe 'applies' do
        before do
          order.add discounted, quantity: 2
        end
        include_examples 'applies to order'
      end
    end

    describe 'discount code' do
      before { promotion.discount_code = 'DiscountMe!' }
      include_examples 'does not apply to order'

      describe 'applies - using adjustment token' do
        before do
          order.fee_adjustments.offer_token.create! \
            discount_code:  promotion.discount_code,
            display_name:   'Special discount code',
            price:          GBP('1.00')
        end
        include_examples 'applies to order'
      end

      describe 'applies - using coupon code' do
        before do
          order.coupon_code = promotion.discount_code
        end
        include_examples 'applies to order'
      end
    end

    describe 'negative balance' do
      before { promotion.discount = GBP '99_999.99' }
      include_examples 'does not apply to order'
    end
  end
end
