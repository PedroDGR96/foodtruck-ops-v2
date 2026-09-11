require "rails_helper"

RSpec.describe ApplicationPolicy do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
  let(:kitchen) { Tenancy.with_business(business) { create(:user, :kitchen, business: business) } }
  let(:other_business) { create(:business) }
  let(:other_owner) { Tenancy.with_business(other_business) { create(:user, :owner, business: other_business) } }

  def policy_for(user, record = Object)
    described_class.new(user, record)
  end

  describe "role helpers" do
    it "owner? returns true for owner and false for cashier/kitchen" do
      expect(policy_for(owner).send(:owner?)).to be(true)
      expect(policy_for(cashier).send(:owner?)).to be(false)
      expect(policy_for(kitchen).send(:owner?)).to be(false)
    end

    it "cashier? returns true for cashier and false for owner/kitchen" do
      expect(policy_for(cashier).send(:cashier?)).to be(true)
      expect(policy_for(owner).send(:cashier?)).to be(false)
      expect(policy_for(kitchen).send(:cashier?)).to be(false)
    end

    it "kitchen? returns true for kitchen and false for owner/cashier" do
      expect(policy_for(kitchen).send(:kitchen?)).to be(true)
      expect(policy_for(owner).send(:kitchen?)).to be(false)
      expect(policy_for(cashier).send(:kitchen?)).to be(false)
    end

    it "staff? returns true for owner, cashier, and kitchen" do
      expect(policy_for(owner).send(:staff?)).to be(true)
      expect(policy_for(cashier).send(:staff?)).to be(true)
      expect(policy_for(kitchen).send(:staff?)).to be(true)
    end
  end

  describe "initialize" do
    it "stores user and record" do
      policy = policy_for(owner)
      expect(policy.user).to eq(owner)
      expect(policy.record).to eq(Object)
    end
  end

  describe "Scope" do
    it "resolves to all records" do
      Tenancy.with_business(business) do
        scope = ApplicationPolicy::Scope.new(owner, Customer.all)
        expect(scope.resolve.to_a).to eq(Customer.all.to_a)
      end
    end

    it "stores user and scope" do
      Tenancy.with_business(business) do
        scope = ApplicationPolicy::Scope.new(owner, Customer.all)
        expect(scope.user).to eq(owner)
        expect(scope.scope).to eq(Customer.all)
      end
    end
  end
end
