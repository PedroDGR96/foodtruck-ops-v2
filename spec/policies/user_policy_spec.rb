require "rails_helper"

RSpec.describe UserPolicy do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
  let(:kitchen) { Tenancy.with_business(business) { create(:user, :kitchen, business: business) } }

  def policy_for(user, record = Object)
    described_class.new(user, record)
  end

  describe "index?" do
    it "returns true for owner" do
      expect(policy_for(owner).index?).to be(true)
    end

    it "returns false for cashier" do
      expect(policy_for(cashier).index?).to be(false)
    end

    it "returns false for kitchen" do
      expect(policy_for(kitchen).index?).to be(false)
    end
  end

  describe "new?" do
    it "returns true for owner" do
      expect(policy_for(owner).new?).to be(true)
    end

    it "returns false for cashier" do
      expect(policy_for(cashier).new?).to be(false)
    end

    it "returns false for kitchen" do
      expect(policy_for(kitchen).new?).to be(false)
    end
  end

  describe "create?" do
    it "returns true for owner" do
      expect(policy_for(owner).create?).to be(true)
    end

    it "returns false for cashier" do
      expect(policy_for(cashier).create?).to be(false)
    end

    it "returns false for kitchen" do
      expect(policy_for(kitchen).create?).to be(false)
    end
  end

  describe "edit?" do
    it "returns true for owner" do
      expect(policy_for(owner).edit?).to be(true)
    end

    it "returns false for cashier" do
      expect(policy_for(cashier).edit?).to be(false)
    end

    it "returns false for kitchen" do
      expect(policy_for(kitchen).edit?).to be(false)
    end
  end

  describe "update?" do
    it "returns true for owner" do
      expect(policy_for(owner).update?).to be(true)
    end

    it "returns false for cashier" do
      expect(policy_for(cashier).update?).to be(false)
    end

    it "returns false for kitchen" do
      expect(policy_for(kitchen).update?).to be(false)
    end
  end
end
