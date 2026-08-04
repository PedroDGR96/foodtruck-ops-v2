require "rails_helper"

RSpec.describe ProductVariant, type: :model do
  let(:business) { create(:business) }
  let(:product) { Tenancy.with_business(business) { create(:product, business: business) } }

  def build_variant(**overrides)
    build(:product_variant, business: business, product: product, **overrides)
  end

  it "builds a valid variant" do
    Tenancy.with_business(business) { expect(build_variant).to be_valid }
  end

  describe "price validation" do
    it "allows a nil price (falls back to the product price)" do
      Tenancy.with_business(business) { expect(build_variant(price: nil)).to be_valid }
    end

    it "rejects a negative price" do
      Tenancy.with_business(business) do
        variant = build_variant(price: -0.5)
        expect(variant).not_to be_valid
        expect(variant.errors[:price]).to be_present
      end
    end

    it "falls back to the product price" do
      Tenancy.with_business(business) do
        expect(build_variant(price: nil).effective_price).to eq(product.price)
      end
    end
  end

  describe "stock validation" do
    it "allows a nil stock" do
      Tenancy.with_business(business) { expect(build_variant(stock: nil)).to be_valid }
    end

    it "rejects negative or fractional stock" do
      Tenancy.with_business(business) do
        expect(build_variant(stock: -1)).not_to be_valid
        expect(build_variant(stock: 1.5)).not_to be_valid
      end
    end
  end

  it "requires a product from the same business" do
    other = create(:business)
    foreign_product = Tenancy.with_business(other) { create(:product, business: other) }

    Tenancy.with_business(business) do
      variant = build_variant(product: foreign_product)
      expect(variant).not_to be_valid
      expect(variant.errors[:product]).to be_present
    end
  end

  it "only exposes variants from the current business" do
    mine = Tenancy.with_business(business) { create(:product_variant, business: business, product: product) }
    other = create(:business)
    Tenancy.with_business(other) { create(:product_variant, business: other) }

    Tenancy.with_business(business) { expect(ProductVariant.pluck(:id)).to contain_exactly(mine.id) }
  end

  it "excludes discarded variants from the default scope" do
    variant = Tenancy.with_business(business) { create(:product_variant, business: business, product: product) }
    Tenancy.with_business(business) { variant.discard! }

    Tenancy.with_business(business) do
      expect(ProductVariant.find_by(id: variant.id)).to be_nil
    end
  end
end
