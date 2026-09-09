require "rails_helper"

RSpec.describe ProductAddonPolicy do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }

  def policy_for(user, record = ProductAddon)
    described_class.new(user, record)
  end

  it "inherits the menu-record matrix (owner-managed)" do
    expect(policy_for(owner).index?).to be(true)
    expect(policy_for(owner).show?).to be(true)
    expect(policy_for(owner).create?).to be(true)
    expect(policy_for(owner).update?).to be(true)
    expect(policy_for(owner).destroy?).to be(true)

    expect(policy_for(cashier).index?).to be(true)
    expect(policy_for(cashier).create?).to be(false)
    expect(policy_for(cashier).update?).to be(false)
    expect(policy_for(cashier).destroy?).to be(false)
  end
end
