require "rails_helper"

RSpec.describe CashMovement do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "enums" do
    it "supports income and expense types" do
      movement = within_tenant { build(:cash_movement, movement_type: "income") }

      expect(movement).to be_income
      expect(CashMovement.movement_types.keys).to contain_exactly("income", "expense")
    end

    it "supports all categories" do
      expect(CashMovement.categories.keys).to contain_exactly(
        "refund", "cash_drop", "payout", "other_income", "other_expense"
      )
    end
  end

  describe "validations" do
    it "requires a positive amount" do
      movement = within_tenant { build(:cash_movement, amount: 0) }

      expect(movement).not_to be_valid
    end

    it "requires a reason" do
      movement = within_tenant { build(:cash_movement, reason: nil) }

      expect(movement).not_to be_valid
    end

    it "requires a cash_register" do
      movement = within_tenant { build(:cash_movement, cash_register: nil) }

      expect(movement).not_to be_valid
    end
  end
end
