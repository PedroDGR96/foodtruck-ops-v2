require "rails_helper"

RSpec.describe OrderPolicy do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  def order(status: "paid")
    Tenancy.with_business(business) { create(:order, business: business, status: status) }
  end

  describe "#start_cooking? / #mark_ready?" do
    it "lets kitchen staff and owners drive cooking transitions" do
      [ :kitchen, :owner ].each do |role|
        policy = described_class.new(staff(role), order)
        expect(policy.start_cooking?).to be(true)
        expect(policy.mark_ready?).to be(true)
      end
    end

    it "forbids cashiers from driving cooking transitions" do
      policy = described_class.new(staff(:cashier), order)

      expect(policy.start_cooking?).to be(false)
      expect(policy.mark_ready?).to be(false)
    end
  end
end
