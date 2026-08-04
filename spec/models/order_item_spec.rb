require "rails_helper"

RSpec.describe OrderItem do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "snapshot fields" do
    it "copies the product name and price into the line item" do
      product = within_tenant { create(:product, business: business, price: 7.5) }
      order = within_tenant { create(:order, business: business) }

      item = within_tenant { create(:order_item, order: order, product: product, quantity: 2) }

      expect(item.product_name).to eq(product.name)
      expect(item.unit_price).to eq(7.5)
      expect(item.line_total).to eq(15.0)
    end

    it "keeps the snapshot when the product is later renamed" do
      product = within_tenant { create(:product, business: business, price: 7.5) }
      order = within_tenant { create(:order, business: business) }
      item = within_tenant { create(:order_item, order: order, product: product, quantity: 1) }
      original_name = product.name

      within_tenant { product.update!(name: "Renomeado") }

      expect(item.product_name).to eq(original_name)
    end
  end

  describe "line total computation" do
    it "multiplies unit price by quantity, rounding to cents" do
      order = within_tenant { create(:order, business: business) }

      item = within_tenant { create(:order_item, order: order, unit_price: 0.333, quantity: 3) }

      expect(item.unit_total).to eq(0.33)
      expect(item.line_total).to eq(0.99)
    end

    it "includes add-ons in the unit total" do
      order = within_tenant { create(:order, business: business) }
      item = within_tenant { create(:order_item, order: order, unit_price: 10.0) }
      within_tenant { create(:order_item_addon, order_item: item, price: 2.5) }

      expect(item.addons_total).to eq(2.5)
      expect(item.unit_total).to eq(12.5)
      expect(item.reload.line_total).to eq(12.5)
    end
  end

  describe "validations" do
    def build_item(overrides = {})
      order = within_tenant { build(:order, business: business) }
      product = within_tenant { build(:product, business: business) }
      within_tenant { build(:order_item, order: order, product: product, **overrides) }
    end

    it "requires a product name" do
      expect(build_item(product_name: "")).not_to be_valid
    end

    it "rejects a zero or negative quantity" do
      expect(build_item(quantity: 0)).not_to be_valid
      expect(build_item(quantity: -2)).not_to be_valid
    end

    it "rejects a negative unit price" do
      expect(build_item(unit_price: -1)).not_to be_valid
    end

    it "rejects a product from another business" do
      order = within_tenant { create(:order, business: business) }
      other_product = create(:product)

      item = within_tenant { build(:order_item, order: order, product: other_product) }

      expect(item).not_to be_valid
      expect(item.errors[:product]).to be_present
    end
  end

  describe "totals refresh" do
    it "recomputes the order totals after create and destroy" do
      product = within_tenant { create(:product, business: business, price: 10.0) }
      order = within_tenant { create(:order, business: business) }

      item = within_tenant { create(:order_item, order: order, product: product, quantity: 2) }

      expect(order.reload.total).to eq(20.0)

      within_tenant { item.destroy! }

      expect(order.reload.total).to eq(0.0)
    end

    it "refreshes the line total when an add-on changes" do
      order = within_tenant { create(:order, business: business) }
      item = within_tenant { create(:order_item, order: order, unit_price: 10.0, quantity: 2) }

      addon = within_tenant { create(:order_item_addon, order_item: item, price: 1.0) }
      item.reload

      expect(item.line_total).to eq(22.0)
      expect(order.reload.total).to eq(22.0)

      within_tenant { addon.update!(price: 2.0) }

      expect(item.reload.line_total).to eq(24.0)
      expect(order.reload.total).to eq(24.0)
    end
  end
end
