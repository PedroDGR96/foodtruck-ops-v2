require "rails_helper"

RSpec.describe OrderItemAddon do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "snapshot fields" do
    it "copies the add-on name and price from the catalog" do
      addon_catalog = within_tenant { create(:product_addon, business: business, price: 2.0) }
      order = within_tenant { create(:order, business: business) }
      item = within_tenant { create(:order_item, order: order) }

      snapshot = within_tenant do
        create(:order_item_addon, order_item: item, product_addon: addon_catalog)
      end

      expect(snapshot.name).to eq(addon_catalog.name)
      expect(snapshot.price).to eq(2.0)
    end
  end

  describe "validations" do
    def build_addon(overrides = {})
      order = within_tenant { build(:order, business: business) }
      item = within_tenant { build(:order_item, order: order) }
      within_tenant { build(:order_item_addon, order_item: item, **overrides) }
    end

    it "requires a name" do
      expect(build_addon(name: "")).not_to be_valid
    end

    it "rejects a negative price" do
      expect(build_addon(price: -0.01)).not_to be_valid
    end

    it "rejects an add-on from another business" do
      item = within_tenant { create(:order_item) }
      foreign_addon = create(:product_addon)

      addon = within_tenant { build(:order_item_addon, order_item: item, product_addon: foreign_addon) }

      expect(addon).not_to be_valid
      expect(addon.errors[:product_addon]).to be_present
    end
  end

  describe "parent refresh" do
    it "recomputes the parent line total when destroyed" do
      order = within_tenant { create(:order, business: business) }
      item = within_tenant { create(:order_item, order: order, unit_price: 10.0, quantity: 1) }
      addon = within_tenant { create(:order_item_addon, order_item: item, price: 3.0) }

      expect(item.reload.line_total).to eq(13.0)

      within_tenant { addon.destroy! }

      expect(item.reload.line_total).to eq(10.0)
      expect(order.reload.total).to eq(10.0)
    end
  end
end
