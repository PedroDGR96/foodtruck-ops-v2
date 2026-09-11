require "rails_helper"

RSpec.describe CompliancePolicy do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
  let(:kitchen) { Tenancy.with_business(business) { create(:user, :kitchen, business: business) } }

  def policy_for(user, record = Object)
    described_class.new(user, record)
  end

  describe "show?" do
    it "returns true for owner" do
      expect(policy_for(owner).show?).to be(true)
    end

    it "returns false for cashier" do
      expect(policy_for(cashier).show?).to be(false)
    end

    it "returns false for kitchen" do
      expect(policy_for(kitchen).show?).to be(false)
    end
  end
end
