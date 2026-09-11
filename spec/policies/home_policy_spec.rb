require "rails_helper"

RSpec.describe HomePolicy do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
  let(:kitchen) { Tenancy.with_business(business) { create(:user, :kitchen, business: business) } }

  def policy_for(user)
    described_class.new(user, Object)
  end

  describe "index?" do
    it "returns true for owner" do
      expect(policy_for(owner).index?).to be(true)
    end

    it "returns true for cashier" do
      expect(policy_for(cashier).index?).to be(true)
    end

    it "returns true for kitchen" do
      expect(policy_for(kitchen).index?).to be(true)
    end
  end

  describe "#user" do
    it "stores user" do
      policy = policy_for(owner)
      expect(policy.user).to eq(owner)
    end
  end

  describe "#record" do
    it "stores record" do
      policy = policy_for(owner)
      expect(policy.record).to eq(Object)
    end
  end
end
