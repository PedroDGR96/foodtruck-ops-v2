require "rails_helper"

RSpec.describe CashRegisterLedger do
  let(:business) { create(:business) }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe ".record_refunds!" do
    it "creates expense movements for cash payments on open shifts" do
      register = within_tenant { create(:cash_register, :open, business: business, user: cashier) }
      order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
      payment = within_tenant do
        create(:payment, order: order, method: "cash", amount: 30.0, cash_register: register)
      end
      within_tenant { order.update!(status: "paid", payment_status: "paid") }

      described_class.record_refunds!(payments: [ payment ], order: order, actor: cashier)

      movement = register.cash_movements.last
      expect(movement).to be_expense
      expect(movement.category).to eq("refund")
      expect(movement.amount).to eq(30.0)
    end

    it "skips payments without a cash register" do
      order = within_tenant { create(:order, :open, business: business, total: 20.0, subtotal: 20.0) }
      payment = within_tenant do
        create(:payment, order: order, method: "pix", amount: 20.0)
      end
      within_tenant { order.update!(status: "paid", payment_status: "paid") }

      expect { described_class.record_refunds!(payments: [ payment ], order: order, actor: cashier) }
        .not_to change(CashMovement, :count)
    end

    it "flags reconciliation on closed register after late refund" do
      register = within_tenant do
        create(:cash_register, :open, business: business, user: cashier, opening_amount: 100.0)
      end
      order = within_tenant { create(:order, :open, business: business, total: 25.0, subtotal: 25.0) }
      payment = within_tenant do
        create(:payment, order: order, method: "cash", amount: 25.0, cash_register: register)
      end
      within_tenant { order.update!(status: "paid", payment_status: "paid") }

      register.close!(actual_closing_amount: 125.0, actor: cashier)
      expect(register).to be_reconciled

      described_class.record_refunds!(payments: [ payment ], order: order, actor: cashier)

      register.reload
      expect(register.reconciled).to be(false)
    end
  end
end
