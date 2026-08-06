require "rails_helper"

RSpec.describe CashRegister do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "validations" do
    it "requires a non-negative opening amount" do
      register = within_tenant { build(:cash_register, business: business, opening_amount: -1) }

      expect(register).not_to be_valid
    end

    it "allows zero opening amount" do
      register = within_tenant { build(:cash_register, business: business, opening_amount: 0) }

      expect(register).to be_valid
    end

    it "requires actual_closing_amount when closed" do
      register = within_tenant { build(:cash_register, :closed, business: business, actual_closing_amount: nil) }

      expect(register).not_to be_valid
    end

    it "enforces one open shift per cashier" do
      user = within_tenant { create(:user, :cashier, business: business) }
      within_tenant { create(:cash_register, :open, business: business, user: user) }
      second = within_tenant { build(:cash_register, :open, business: business, user: user) }

      expect(second).not_to be_valid
    end

    it "allows a second shift after closing the first" do
      user = within_tenant { create(:user, :cashier, business: business) }
      first = within_tenant { create(:cash_register, :open, business: business, user: user) }
      within_tenant { first.close!(actual_closing_amount: 100.0) }
      second = within_tenant { build(:cash_register, :open, business: business, user: user) }

      expect(second).to be_valid
    end
  end

  describe "#close!" do
    it "closes the register with reconciliation" do
      register = within_tenant { create(:cash_register, :open, business: business, opening_amount: 100.0) }

      register.close!(actual_closing_amount: 100.0)

      expect(register).to be_closed
      expect(register.drift).to eq(0.0)
      expect(register.reconciled).to be(true)
      expect(register.closed_at).to be_present
    end

    it "records drift on mismatch" do
      register = within_tenant { create(:cash_register, :open, business: business, opening_amount: 100.0) }

      register.close!(actual_closing_amount: 95.0)

      expect(register.drift).to eq(-5.0)
      expect(register.reconciled).to be(false)
    end

    it "raises when already closed" do
      register = within_tenant { create(:cash_register, :closed, business: business) }

      expect { register.close!(actual_closing_amount: 100.0) }
        .to raise_error(CashRegister::ShiftError)
    end
  end

  describe "#expected_closing" do
    it "returns opening + cash sales + movement balance" do
      register = within_tenant do
        create(:cash_register, :open, business: business, opening_amount: 50.0)
      end
      order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
      within_tenant do
        create(:payment, order: order, method: "cash", amount: 30.0, cash_register: register)
      end
      within_tenant do
        create(:cash_movement, cash_register: register, movement_type: "income", category: "cash_drop", amount: 10.0, reason: "Cash in")
      end

      expect(register.expected_closing).to eq(90.0)
    end
  end

  describe "#flag_reconciliation!" do
    it "recalculates drift on a closed register" do
      register = within_tenant { create(:cash_register, :closed, business: business, opening_amount: 100.0, actual_closing_amount: 100.0) }
      order = within_tenant { create(:order, :open, business: business, total: 20.0, subtotal: 20.0) }
      within_tenant do
        create(:payment, order: order, method: "cash", amount: 20.0, cash_register: register)
      end

      register.flag_reconciliation!

      expect(register.expected_closing).to eq(120.0)
      expect(register.drift).to eq(-20.0)
      expect(register.reconciled).to be(false)
    end
  end
end
