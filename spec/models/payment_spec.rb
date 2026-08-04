require "rails_helper"

RSpec.describe Payment do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "enums" do
    it "supports cash, pix and card methods" do
      payment = within_tenant { build(:payment, method: "pix") }

      expect(payment).to be_pix
      expect(Payment.methods.keys).to contain_exactly("cash", "pix", "card")
    end

    it "defaults to the succeeded status" do
      payment = within_tenant { build(:payment) }

      expect(payment).to be_succeeded
    end
  end

  describe "validations" do
    it "requires a positive amount" do
      payment = within_tenant { build(:payment, amount: 0) }

      expect(payment).not_to be_valid

      payment = within_tenant { build(:payment, amount: nil) }

      expect(payment).not_to be_valid
    end

    it "requires an order" do
      payment = within_tenant { build(:payment, order: nil) }

      expect(payment).not_to be_valid
    end

    it "rejects an order from another business" do
      foreign_order = create(:order)

      payment = within_tenant { build(:payment, order: foreign_order, amount: 5.0) }

      expect(payment).not_to be_valid
    end

    it "cannot exceed the remaining order balance" do
      order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }

      payment = within_tenant { build(:payment, order: order, amount: 31.0) }

      expect(payment).not_to be_valid
      expect(payment.errors[:amount]).to include("não pode exceder o saldo restante do pedido")
    end

    it "accepts a payment covering the remaining balance after a partial one" do
      order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
      within_tenant { create(:payment, order: order, amount: 10.0) }

      payment = within_tenant { build(:payment, order: order, amount: 20.0) }

      expect(payment).to be_valid
    end
  end

  describe "scopes" do
    it "filters successful and refunded payments" do
      order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
      ok = within_tenant { create(:payment, order: order, amount: 10.0) }
      refunded = within_tenant { create(:payment, order: order, amount: 5.0, status: "refunded") }

      expect(order.payments.successful.pluck(:id)).to eq([ ok.id ])
      expect(order.payments.refunded.pluck(:id)).to eq([ refunded.id ])
    end
  end
end
