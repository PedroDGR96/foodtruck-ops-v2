require "rails_helper"

RSpec.describe KitchenPolicy do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  describe "#show?" do
    it "lets every staff role open the kitchen display" do
      %i[owner cashier kitchen].each do |role|
        expect(described_class.new(staff(role), :kitchen).show?).to be(true)
      end
    end
  end
end
