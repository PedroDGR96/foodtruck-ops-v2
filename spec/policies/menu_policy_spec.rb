require "rails_helper"

RSpec.describe MenuPolicy do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  it "lets any authenticated viewer open the menu" do
    %i[owner cashier kitchen].each do |role|
      expect(described_class.new(staff(role), :menu).show?).to be(true)
    end
  end
end
