require "rails_helper"

RSpec.describe CashRegisterPolicy do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
  let(:kitchen) { Tenancy.with_business(business) { create(:user, :kitchen, business: business) } }

  def policy_for(user, record = CashRegister)
    described_class.new(user, record)
  end

  describe "#index?" do
    it "allows all staff roles" do
      expect(policy_for(owner).index?).to be(true)
      expect(policy_for(cashier).index?).to be(true)
      expect(policy_for(kitchen).index?).to be(true)
    end
  end

  describe "#show?" do
    it "allows all staff roles" do
      expect(policy_for(owner).show?).to be(true)
      expect(policy_for(cashier).show?).to be(true)
      expect(policy_for(kitchen).show?).to be(true)
    end
  end

  describe "#create?" do
    it "allows owner and cashier" do
      expect(policy_for(owner).create?).to be(true)
      expect(policy_for(cashier).create?).to be(true)
    end

    it "denies kitchen" do
      expect(policy_for(kitchen).create?).to be(false)
    end
  end

  describe "#close?" do
    let(:register) do
      Tenancy.with_business(business) { create(:cash_register, :open, business: business, user: cashier) }
    end

    it "allows the owner on any register" do
      expect(policy_for(owner, register).close?).to be(true)
    end

    it "allows the cashier on their own open register" do
      expect(policy_for(cashier, register).close?).to be(true)
    end

    it "denies the cashier on someone else's register" do
      other_cashier = Tenancy.with_business(business) { create(:user, :cashier, business: business) }
      expect(policy_for(other_cashier, register).close?).to be(false)
    end

    it "denies closing a closed register" do
      closed = Tenancy.with_business(business) { create(:cash_register, :closed, business: business, user: cashier) }
      expect(policy_for(cashier, closed).close?).to be(false)
    end

    it "denies the cashier on someone else's closed register" do
      other_cashier = Tenancy.with_business(business) { create(:user, :cashier, business: business) }
      closed = Tenancy.with_business(business) { create(:cash_register, :closed, business: business, user: other_cashier) }
      expect(policy_for(cashier, closed).close?).to be(false)
    end
  end

  describe "#record_movement?" do
    let(:open_register) do
      Tenancy.with_business(business) { create(:cash_register, :open, business: business, user: cashier) }
    end

    let(:closed_register) do
      Tenancy.with_business(business) { create(:cash_register, :closed, business: business, user: cashier) }
    end

    it "allows the owner on any register" do
      expect(policy_for(owner, open_register).record_movement?).to be(true)
      expect(policy_for(owner, closed_register).record_movement?).to be(true)
    end

    it "allows the cashier on their own open register" do
      expect(policy_for(cashier, open_register).record_movement?).to be(true)
    end

    it "denies the cashier on a closed register" do
      expect(policy_for(cashier, closed_register).record_movement?).to be(false)
    end

    it "denies the cashier on someone else's register" do
      other = Tenancy.with_business(business) { create(:user, :cashier, business: business) }
      expect(policy_for(other, open_register).record_movement?).to be(false)
    end
  end
end
