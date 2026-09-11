require "rails_helper"

RSpec.describe BusinessPolicy do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
  let(:kitchen) { Tenancy.with_business(business) { create(:user, :kitchen, business: business) } }

  def policy_for(user, record = business)
    described_class.new(user, record)
  end

  describe "#edit?" do
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

  describe "#update?" do
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

  describe "Scope" do
    it "resolves to all businesses" do
      Tenancy.with_business(business) do
        scope = BusinessPolicy::Scope.new(owner, Business.all)
        expect(scope.resolve.to_a).to eq(Business.all.to_a)
      end
    end
  end
end
