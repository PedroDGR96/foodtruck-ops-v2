require "rails_helper"

RSpec.describe CustomerPolicy do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
  let(:kitchen) { Tenancy.with_business(business) { create(:user, :kitchen, business: business) } }

  def policy_for(user, record = Customer)
    described_class.new(user, record)
  end

  it "lets every staff role index and show customers" do
    expect(policy_for(owner).index?).to be(true)
    expect(policy_for(owner).show?).to be(true)
    expect(policy_for(cashier).index?).to be(true)
    expect(policy_for(cashier).show?).to be(true)
    expect(policy_for(kitchen).index?).to be(true)
    expect(policy_for(kitchen).show?).to be(true)
  end

  it "lets owner and cashier create/update customers" do
    expect(policy_for(owner).create?).to be(true)
    expect(policy_for(owner).update?).to be(true)
    expect(policy_for(cashier).create?).to be(true)
    expect(policy_for(cashier).update?).to be(true)

    expect(policy_for(kitchen).create?).to be(false)
    expect(policy_for(kitchen).update?).to be(false)
  end

  it "restricts destroy (archive) to the owner" do
    expect(policy_for(owner).destroy?).to be(true)
    expect(policy_for(cashier).destroy?).to be(false)
    expect(policy_for(kitchen).destroy?).to be(false)
  end

  it "scope resolves to all records — no policy-level filtering (controller uses BusinessScoped default_scope)" do
    Tenancy.with_business(business) do
      scope = CustomerPolicy::Scope.new(owner, Customer.all)
      expect(scope.resolve.to_a).to eq(Customer.all.to_a)
    end
  end

  it "new? and edit? are aliases to create? and update?" do
    expect(policy_for(owner).new?).to be(true)
    expect(policy_for(owner).edit?).to be(true)
    expect(policy_for(cashier).new?).to be(true)
    expect(policy_for(cashier).edit?).to be(true)

    expect(policy_for(kitchen).new?).to be(false)
    expect(policy_for(kitchen).edit?).to be(false)
  end
end
