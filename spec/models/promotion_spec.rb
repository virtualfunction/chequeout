require File.expand_path('../../../spec/spec_helper', __FILE__)

Offer = Chequeout::Offer

describe Promotion do
  
  [ Order, Product, Promotion ].each &:destroy_all
  let(:order) { FactoryGirl.create :filled_basket_order }
  let(:promotion) { FactoryGirl.build :promotion }

  specify { Promotion.should be < Offer::Promotional }
  specify { FeeAdjustment.should be < Offer::DiscountedProductAdjustment }
  specify { FeeAdjustment.should be < Offer::DiscountCodeAdjustment }

  describe 'offer discount' do
    let(:coupons) { order.fee_adjustments.coupon }
    describe 'fixed' do
      before do
        promotion.apply_to order
      end

      it 'should alter the total' do
        coupons.count.should == 1
        coupons.first.price.should == GBP('-1.99')
      end
    end
    
    describe 'percentage - 20%' do
      before do
        promotion.update_attributes :discount_strategy => 'percentage', :discount_amount => 20
        promotion.apply_to order
      end

      it 'should alter the total' do
        coupons.count.should == 1
        coupons.first.price.should == GBP('-4.00')
      end
    end
  end

  describe 'offer criteria' do
    shared_examples 'does not apply to order' do    
      it 'is rejected' do
        promotion.applicable_for?(order).should be_false
      end
    end
    
    shared_examples 'applies to order' do
      it 'is accepted' do
        promotion.applicable_for?(order).should be_true
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
      before do
        promotion.discounted_item = FactoryGirl.create :product, :display_name => 'Another item'
      end
      
      pending do # Broken
        include_examples 'does not apply to order'
      end
      
      describe 'applies' do
        before do 
          order.add promotion.discounted_item, :quantity => 2
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
            :discount_code  => promotion.discount_code, 
            :display_name   => 'Special discount code',
            :price          => GBP('1.00')
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
