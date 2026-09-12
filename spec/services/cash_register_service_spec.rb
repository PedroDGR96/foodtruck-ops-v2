require "rails_helper"

RSpec.describe CashRegisterService do
  let(:business) { create(:business) }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe ".open!" do
    it "saves and audits the register" do
      register = within_tenant { build(:cash_register, business: business, user: cashier) }

      result = described_class.open!(register: register, actor: cashier)

      expect(result).to be_persisted
      expect(result).to be_open
      audit = AuditLog.where(action: "shift_opened", resource_id: result.id).last
      expect(audit).to be_present
    end
  end

  describe ".close!" do
    it "closes the register" do
      register = within_tenant { create(:cash_register, :open, business: business, user: cashier) }

      described_class.close!(register: register, actual_closing_amount: 100.0, actor: cashier)

      expect(register.reload).to be_closed
    end

    it "rejects a blank closing amount instead of closing at zero" do
      register = within_tenant { create(:cash_register, :open, business: business, user: cashier) }

      expect { described_class.close!(register: register, actual_closing_amount: "", actor: cashier) }
        .to raise_error(ActiveRecord::RecordInvalid)

      expect(register.reload).to be_open
    end
  end

  describe ".record_movement!" do
    it "creates an income movement" do
      register = within_tenant { create(:cash_register, :open, business: business, user: cashier) }

      movement = described_class.record_movement!(
        register: register,
        movement_type: "income",
        category: "cash_drop",
        amount: 50.0,
        reason: "Cash deposit",
        actor: cashier
      )

      expect(movement).to be_persisted
      expect(movement).to be_income
      expect(movement.amount).to eq(50.0)
    end

    it "creates an expense movement" do
      register = within_tenant { create(:cash_register, :open, business: business, user: cashier) }

      movement = described_class.record_movement!(
        register: register,
        movement_type: "expense",
        category: "payout",
        amount: 25.0,
        reason: "Supplier payment",
        actor: cashier
      )

      expect(movement).to be_persisted
      expect(movement).to be_expense
    end

    it "flags reconciliation on closed register" do
      register = within_tenant { create(:cash_register, :closed, business: business, opening_amount: 100.0, actual_closing_amount: 100.0, user: cashier) }

      described_class.record_movement!(
        register: register,
        movement_type: "expense",
        category: "payout",
        amount: 10.0,
        reason: "Late payout",
        actor: cashier
      )

      expect(Tenancy.with_business(business) { register.reload.drift }).to eq(10.0)
    end
  end

  describe "drawer reconciliation" do
    it "lands a cash payment on an open shift in that shift's drawer total" do
      register = within_tenant { create(:cash_register, :open, business: business, user: cashier, opening_amount: 100.0) }
      order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
      payment = order.payments.build(method: "cash", amount: 30.0)

      within_tenant do
        OrderLifecycle.new(order, cashier).record_payment!(payment)
      end

      within_tenant { register.reload }
      expect(within_tenant { register.cash_sales }).to eq(30.0)
      expect(within_tenant { register.expected_closing }).to eq(130.0)
    end

    it "creates exactly ONE expense movement per refunded cash payment" do
      register = within_tenant { create(:cash_register, :open, business: business, user: cashier, opening_amount: 100.0) }
      order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
      payment = within_tenant do
        create(:payment, order: order, method: "cash", amount: 30.0, cash_register: register)
      end
      within_tenant { order.update!(status: "paid", payment_status: "paid") }

      within_tenant do
        CashRegisterLedger.record_refunds!(payments: [ payment ], order: order, actor: cashier)
      end

      movements = within_tenant { register.cash_movements.reload.to_a }
      expect(movements.size).to eq(1)
      expect(movements.first).to be_expense
      expect(movements.first.category).to eq("refund")
      expect(movements.first.amount).to eq(30.0)
    end
  end
end
