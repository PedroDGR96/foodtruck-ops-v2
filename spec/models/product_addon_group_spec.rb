require "rails_helper"

RSpec.describe ProductAddonGroup, type: :model do
  let(:business) { create(:business) }
  let(:product) { Tenancy.with_business(business) { create(:product, business: business) } }

  def build_group(**overrides)
    build(:product_addon_group, business: business, product: product, **overrides)
  end

  it "builds a valid addon group" do
    Tenancy.with_business(business) { expect(build_group).to be_valid }
  end

  describe "selection range validation" do
    it "rejects a negative minimum" do
      Tenancy.with_business(business) do
        expect(build_group(min_select: -1)).not_to be_valid
      end
    end

    it "rejects a maximum below the minimum" do
      Tenancy.with_business(business) do
        group = build_group(min_select: 2, max_select: 1)
        expect(group).not_to be_valid
        expect(group.errors[:max_select]).to be_present
      end
    end

    it "allows an unlimited maximum" do
      Tenancy.with_business(business) { expect(build_group(max_select: nil)).to be_valid }
    end
  end

  it "requires a product from the same business" do
    other = create(:business)
    foreign_product = Tenancy.with_business(other) { create(:product, business: other) }

    Tenancy.with_business(business) do
      group = build_group(product: foreign_product)
      expect(group).not_to be_valid
      expect(group.errors[:product]).to be_present
    end
  end

  it "only exposes groups from the current business" do
    mine = Tenancy.with_business(business) { create(:product_addon_group, business: business, product: product) }
    other = create(:business)
    Tenancy.with_business(other) { create(:product_addon_group, business: other) }

    Tenancy.with_business(business) { expect(ProductAddonGroup.pluck(:id)).to contain_exactly(mine.id) }
  end

  it "excludes discarded groups from the default scope" do
    group = Tenancy.with_business(business) { create(:product_addon_group, business: business, product: product) }
    Tenancy.with_business(business) { group.discard! }

    Tenancy.with_business(business) do
      expect(ProductAddonGroup.find_by(id: group.id)).to be_nil
    end
  end
end
