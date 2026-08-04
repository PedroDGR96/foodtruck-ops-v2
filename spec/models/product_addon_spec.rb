require "rails_helper"

RSpec.describe ProductAddon, type: :model do
  let(:business) { create(:business) }
  let(:group) { Tenancy.with_business(business) { create(:product_addon_group, business: business) } }

  def build_addon(**overrides)
    build(:product_addon, business: business, product_addon_group: group, **overrides)
  end

  it "builds a valid addon" do
    Tenancy.with_business(business) { expect(build_addon).to be_valid }
  end

  describe "price validation" do
    it "rejects a negative price" do
      Tenancy.with_business(business) do
        addon = build_addon(price: -1)
        expect(addon).not_to be_valid
        expect(addon.errors[:price]).to be_present
      end
    end

    it "allows zero (included)" do
      Tenancy.with_business(business) { expect(build_addon(price: 0)).to be_valid }
    end
  end

  it "requires a group from the same business" do
    other = create(:business)
    foreign_group = Tenancy.with_business(other) { create(:product_addon_group, business: other) }

    Tenancy.with_business(business) do
      addon = build_addon(product_addon_group: foreign_group)
      expect(addon).not_to be_valid
      expect(addon.errors[:product_addon_group]).to be_present
    end
  end

  it "only exposes addons from the current business" do
    mine = Tenancy.with_business(business) { create(:product_addon, business: business, product_addon_group: group) }
    other = create(:business)
    Tenancy.with_business(other) { create(:product_addon, business: other) }

    Tenancy.with_business(business) { expect(ProductAddon.pluck(:id)).to contain_exactly(mine.id) }
  end

  it "excludes discarded addons from the default scope" do
    addon = Tenancy.with_business(business) { create(:product_addon, business: business, product_addon_group: group) }
    Tenancy.with_business(business) { addon.discard! }

    Tenancy.with_business(business) do
      expect(ProductAddon.find_by(id: addon.id)).to be_nil
    end
  end
end
