require "rails_helper"

RSpec.describe Category, type: :model do
  let(:business) { create(:business) }

  def build_category(**overrides)
    build(:category, business: business, **overrides)
  end

  it "builds a valid category" do
    Tenancy.with_business(business) { expect(build_category).to be_valid }
  end

  it "requires a name" do
    Tenancy.with_business(business) do
      category = build_category(name: "")
      expect(category).not_to be_valid
      expect(category.errors[:name]).to be_present
    end
  end

  it "enforces unique names within a business" do
    Tenancy.with_business(business) { create(:category, business: business, name: "Lanches") }

    Tenancy.with_business(business) do
      duplicate = build_category(name: "Lanches")
      expect(duplicate).not_to be_valid
    end
  end

  it "allows the same name across businesses" do
    other = create(:business)
    Tenancy.with_business(business) { create(:category, business: business, name: "Lanches") }

    Tenancy.with_business(other) { expect(build(:category, business: other, name: "Lanches")).to be_valid }
  end

  describe "tenancy" do
    it "only exposes categories from the current business" do
      first = Tenancy.with_business(business) { create(:category, business: business) }
      other = create(:business)
      Tenancy.with_business(other) { create(:category, business: other) }

      Tenancy.with_business(business) do
        expect(Category.pluck(:id)).to contain_exactly(first.id)
      end
    end
  end

  describe "soft delete" do
    it "excludes discarded categories from the default scope" do
      category = Tenancy.with_business(business) { create(:category, business: business) }
      Tenancy.with_business(business) { category.discard! }

      Tenancy.with_business(business) do
        expect(Category.find_by(id: category.id)).to be_nil
        expect(Category.with_discarded.find_by(id: category.id)).to be_present
      end
    end

    it "restores a discarded category" do
      category = Tenancy.with_business(business) { create(:category, business: business) }
      Tenancy.with_business(business) { category.discard! }
      Tenancy.with_business(business) { category.restore! }

      Tenancy.with_business(business) { expect(Category.find(category.id)).to be_present }
    end
  end
end
