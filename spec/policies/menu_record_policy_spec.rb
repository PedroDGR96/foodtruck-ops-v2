require "rails_helper"

RSpec.describe MenuRecordPolicy do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def policy_for(user)
    described_class.new(user, Category)
  end

  it "lets every staff role list and show menu records" do
    %i[owner cashier kitchen].each do |role|
      expect(described_class.new(staff(role), Category).index?).to be(true)
      expect(described_class.new(staff(role), Category).show?).to be(true)
    end
  end

  it "restricts create, update, new and edit to the owner" do
    expect(policy_for(owner).create?).to be(true)
    expect(policy_for(owner).update?).to be(true)
    expect(policy_for(owner).new?).to be(true)
    expect(policy_for(owner).edit?).to be(true)

    expect(policy_for(cashier).create?).to be(false)
    expect(policy_for(cashier).update?).to be(false)
    expect(policy_for(kitchen).create?).to be(false)
    expect(policy_for(kitchen).update?).to be(false)
  end

  it "restricts destroy to the owner" do
    expect(policy_for(owner).destroy?).to be(true)
    expect(policy_for(cashier).destroy?).to be(false)
    expect(policy_for(kitchen).destroy?).to be(false)
  end
end
