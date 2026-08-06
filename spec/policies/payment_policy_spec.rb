require "rails_helper"

RSpec.describe PaymentPolicy do
  let(:business) { create(:business) }
  let(:order) { Tenancy.with_business(business) { create(:order, business: business) } }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def policy_for(user)
    described_class.new(user, order)
  end

  it "lets owners and cashiers open and create payments" do
    [ owner, cashier ].each do |user|
      expect(policy_for(user).new?).to be(true)
      expect(policy_for(user).create?).to be(true)
    end
  end

  it "denies kitchen staff from creating payments" do
    expect(policy_for(kitchen).new?).to be(false)
    expect(policy_for(kitchen).create?).to be(false)
  end

  it "lets every staff role view payments" do
    [ owner, cashier, kitchen ].each do |user|
      expect(policy_for(user).show?).to be(true)
    end
  end
end
