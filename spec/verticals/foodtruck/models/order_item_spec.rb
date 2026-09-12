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
    it "captures the product price at time of order creation and retains it after price changes" do
      # Set up a product with an initial price
      product = within_tenant { create(:product, business: business, price: 10.0) }

      # Create an order item at that price
      order = within_tenant { create(:order, business: business) }
      item = within_tenant { create(:order_item, order: order, product: product, quantity: 2) }

      expect(item.unit_price).to eq(10.0)
      expect(item.line_total).to eq(20.0)

      # Change the product price AFTER the order is created
      within_tenant do
        product.update!(price: 25.0)
      end

      # The order item should STILL show the original price (snapshot semantics)
      expect(item.reload.unit_price).to eq(10.0)
      expect(item.reload.line_total).to eq(20.0)

      # Verify the product itself reflects the new price
      within_tenant { expect(product.reload.price).to eq(25.0) }
    end

    it "captures the unit total (price + addons) at time of creation" do
      addon_catalog = within_tenant { create(:product_addon, business: business, price: 3.0) }
      product = within_tenant { create(:product, business: business, price: 10.0) }

      order = within_tenant { create(:order, business: business) }
      item = within_tenant { create(:order_item, order: order, product: product, quantity: 2) }
      addon_snapshot = within_tenant { create(:order_item_addon, order_item: item, product_addon: addon_catalog) }

      expect(item.unit_total).to eq(13.0)
      expect(item.line_total).to eq(26.0)

      # Change the add-on price after creation
      within_tenant do
        addon_catalog.update!(price: 5.0)
      end

      # The snapshot should still show the original unit total
      expect(item.reload.unit_total).to eq(13.0)
      expect(item.reload.line_total).to eq(26.0)
    end

    it "retains line totals across multiple price changes" do
      product = within_tenant { create(:product, business: business, price: 5.0) }

      order = within_tenant { create(:order, business: business) }
      item = within_tenant { create(:order_item, order: order, product: product, quantity: 3) }

      expect(item.line_total).to eq(15.0)

      # Multiple price changes should not affect the snapshot
      within_tenant do
        product.update!(price: 7.0)
        product.update!(price: 9.0)
      end

      expect(item.reload.line_total).to eq(15.0)
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

    it "rejects a non-positive quantity" do
      expect(build_item(quantity: 0)).not_to be_valid
      expect(build_item(quantity: -1)).not_to be_valid
    end

    it "accepts zero as a valid unit price" do
      expect(build_item(unit_price: 0.0)).to be_valid
    end

    it "rejects a negative unit price" do
      expect(build_item(unit_price: -0.01)).not_to be_valid
    end

    it "requires an associated order" do
      product = within_tenant { create(:product, business: business) }
      item = within_tenant { build(:order_item, product: product) }

      expect(item).not_to be_valid
      expect(item.errors[:order]).to be_present
    end
  end

  describe "parent refresh" do
    it "recomputes the order total when an item is updated" do
      order = within_tenant { create(:order, business: business) }
      item = within_tenant { create(:order_item, order: order, unit_price: 10.0, quantity: 2) }

      expect(order.reload.total).to eq(20.0)

      within_tenant do
        item.update!(unit_price: 15.0)
      end

      expect(item.reload.line_total).to eq(30.0)
      expect(order.reload.total).to eq(30.0)
    end

    it "recomputes the order total when an item is destroyed" do
      order = within_tenant { create(:order, business: business) }
      item1 = within_tenant { create(:order_item, order: order, unit_price: 5.0, quantity: 2) }
      item2 = within_tenant { create(:order_item, order: order, unit_price: 3.0, quantity: 4) }

      expect(order.reload.total).to eq(22.0)

      within_tenant { item1.destroy! }

      expect(item2.reload.line_total).to eq(12.0)
      expect(order.reload.total).to eq(12.0)
    end
  end
end
