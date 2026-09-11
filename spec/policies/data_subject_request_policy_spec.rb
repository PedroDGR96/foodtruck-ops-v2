require "rails_helper"

RSpec.describe DataSubjectRequestPolicy do
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

    it "returns false for cashier and kitchen" do
      expect(policy_for(cashier).index?).to be(false)
      expect(policy_for(kitchen).index?).to be(false)
    end
  end

  describe "show?" do
    it "returns true for owner" do
      expect(policy_for(owner).show?).to be(true)
    end

    it "returns false for cashier and kitchen" do
      expect(policy_for(cashier).show?).to be(false)
      expect(policy_for(kitchen).show?).to be(false)
    end
  end

  describe "create?" do
    it "returns true for owner, cashier, and kitchen" do
      expect(policy_for(owner).create?).to be(true)
      expect(policy_for(cashier).create?).to be(true)
      expect(policy_for(kitchen).create?).to be(true)
    end
  end

  describe "new?" do
    it "returns true for owner, cashier, and kitchen" do
      expect(policy_for(owner).new?).to be(true)
      expect(policy_for(cashier).new?).to be(true)
      expect(policy_for(kitchen).new?).to be(true)
    end
  end

  describe "update?" do
    it "returns true for owner" do
      expect(policy_for(owner).update?).to be(true)
    end

    it "returns false for cashier and kitchen" do
      expect(policy_for(cashier).update?).to be(false)
      expect(policy_for(kitchen).update?).to be(false)
    end
  end

  describe "Scope" do
    it "resolves to records scoped by business_id" do
      Tenancy.with_business(business) do
        scope = described_class::Scope.new(owner, DataSubjectRequest.all)
        resolved = scope.resolve.to_a
        expect(resolved).to eq(DataSubjectRequest.all.to_a)
      end
    end

    it "stores user and scope" do
      Tenancy.with_business(business) do
        scope = described_class::Scope.new(owner, DataSubjectRequest.all)
        expect(scope.user).to eq(owner)
        expect(scope.scope).to eq(DataSubjectRequest.all)
      end
    end
  end
end
