require "rails_helper"

RSpec.describe Product, type: :model do
  let(:business) { create(:business) }
  let(:category) { Tenancy.with_business(business) { create(:category, business: business) } }

  def build_product(**overrides)
    build(:product, business: business, category: category, **overrides)
  end

  it "builds a valid product" do
    Tenancy.with_business(business) { expect(build_product).to be_valid }
  end

  describe "price validation" do
    it "requires a price" do
      Tenancy.with_business(business) do
        product = build_product(price: nil)
        expect(product).not_to be_valid
        expect(product.errors[:price]).to be_present
      end
    end

    it "rejects a negative price" do
      Tenancy.with_business(business) do
        product = build_product(price: -1)
        expect(product).not_to be_valid
        expect(product.errors[:price]).to be_present
      end
    end

    it "accepts zero" do
      Tenancy.with_business(business) { expect(build_product(price: 0)).to be_valid }
    end

    it "stores prices with two decimal places" do
      product = Tenancy.with_business(business) { build_product(price: 12.345) }
      Tenancy.with_business(business) { product.save! }

      Tenancy.with_business(business) { expect(product.reload.price).to eq(BigDecimal("12.35")) }
    end
  end

  it "requires a category from the same business" do
    other = create(:business)
    foreign_category = Tenancy.with_business(other) { create(:category, business: other) }

    Tenancy.with_business(business) do
      product = build_product(category: foreign_category)
      expect(product).not_to be_valid
      expect(product.errors[:category]).to be_present
    end
  end

  it "exposes the status enum" do
    product = Tenancy.with_business(business) { create(:product, business: business, category: category) }
    expect(product).to be_available

    Tenancy.with_business(business) { product.unavailable! }
    expect(product).to be_unavailable
  end

  describe "tenancy" do
    it "only exposes products from the current business" do
      mine = Tenancy.with_business(business) { create(:product, business: business, category: category) }
      other = create(:business)
      Tenancy.with_business(other) do
        other_category = create(:category, business: other)
        create(:product, business: other, category: other_category)
      end

      Tenancy.with_business(business) do
        expect(Product.pluck(:id)).to contain_exactly(mine.id)
      end
    end
  end

  describe "soft delete" do
    it "excludes discarded products from the default scope" do
      product = Tenancy.with_business(business) { create(:product, business: business, category: category) }
      Tenancy.with_business(business) { product.discard! }

      Tenancy.with_business(business) do
        expect(Product.find_by(id: product.id)).to be_nil
        expect(Product.with_discarded.find_by(id: product.id)).to be_present
      end
    end
  end
end
