require "rails_helper"

# Money arithmetic in this app is plain numeric `round(2)` math on Order's
# subtotal/total columns, computed by `OrderCart#recompute_totals_in_memory`
# (per-line `(unit_price + addons).round(2) * quantity` then `.round(2)`, and
# `subtotal + tax + delivery_fee` rounded). These property examples pin down
# that rounding is exact: half-cent boundaries, cents-exactness and no float
# drift, mirroring how the characterization specs treat the other cart math.
RSpec.describe "money rounding" do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "half-cent boundaries" do
    it "rounds a single half-cent unit up to the next cent" do
      product = within_tenant { create(:product, business: business, price: 10.005) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product)

      expect(order.reload.total).to eq(10.01)
    end

    it "rounds a half-cent below unit down" do
      product = within_tenant { create(:product, business: business, price: 10.004) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product)

      expect(order.reload.total).to eq(10.0)
    end

    it "rounds each half-cent unit before multiplying by quantity" do
      product = within_tenant { create(:product, business: business, price: 0.005) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, quantity: 3)

      # The per-line arithmetic is (unit.round(2)) * quantity .round(2):
      # 0.005 -> 0.01 per unit, then 3 * 0.01 = 0.03.
      expect(order.reload.total).to eq(0.03)
    end

    it "sums two half-cent items into an exact cent" do
      low = within_tenant { create(:product, business: business, price: 0.004) }
      high = within_tenant { create(:product, business: business, price: 0.006) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: low, quantity: 1)
      OrderCart.add_item(order, product: high, quantity: 1)

      expect(order.reload.total).to eq(0.01)
    end

    it "rounds an addon price at the half-cent boundary inside the line" do
      group = within_tenant { create(:product_addon_group, business: business) }
      addon = within_tenant { create(:product_addon, business: business, product_addon_group: group, price: 0.005) }
      product = within_tenant { create(:product, business: business, price: 0.0) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, addons: [ addon ])

      expect(order.reload.total).to eq(0.01)
    end
  end

  describe "many-item sums" do
    it "sums 250 identical items without drift" do
      product = within_tenant { create(:product, business: business, price: 0.37) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, quantity: 250)

      expect(order.reload.total).to eq(92.5)
    end

    it "sums ten thousand cents items exactly" do
      product = within_tenant { create(:product, business: business, price: 0.01) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, quantity: 10_000)

      expect(order.reload.total).to eq(100.0)
    end

    it "stays exact across repeated quantity bumps on the same line" do
      product = within_tenant { create(:product, business: business, price: 9.99) }
      order = within_tenant { create(:order, business: business) }

      7.times { OrderCart.add_item(order, product: product, quantity: 1) }

      expect(order.reload.total).to eq(69.93)
    end

    it "keeps the many-item subtotal separate from tax and delivery fee" do
      product = within_tenant { create(:product, business: business, price: 3.33) }
      order = within_tenant { create(:order, business: business) }
      within_tenant { order.update!(tax: 1.11, delivery_fee: 2.22) }

      OrderCart.add_item(order, product: product, quantity: 100)

      expect(order.reload.subtotal).to eq(333.0)
      expect(order.reload.total).to eq(336.33)
    end
  end

  describe "cents-exact" do
    it "keeps the cent amount intact through cart operations" do
      product = within_tenant { create(:product, business: business, price: 12.34) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product)

      # subtotal/total are stored in cents-exact whole-penny floats.
      expect(order.reload.subtotal * 100).to eq(1_234.0)
      expect(order.reload.total * 100).to eq(1_234.0)
    end

    it "preserves exact cents after an addon arithmetic change" do
      group = within_tenant { create(:product_addon_group, business: business) }
      addon = within_tenant { create(:product_addon, business: business, product_addon_group: group, price: 1.5) }
      product = within_tenant { create(:product, business: business, price: 10.5) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, addons: [ addon ])

      expect(order.reload.total * 100).to eq(1_200.0)
    end
  end

  describe "no float drift" do
    it "does not accumulate artifacts across many distinct subtotal recomputations" do
      product = within_tenant { create(:product, business: business, price: 0.1) }
      order = within_tenant { create(:order, business: business) }

      50.times { OrderCart.add_item(order, product: product, quantity: 1) }

      expect(order.reload.total).to eq(5.0)
      expect(order.reload.total).to eq(order.reload.subtotal)
    end

    it "round-trips 0.01 a thousand times through the arithmetic" do
      product = within_tenant { create(:product, business: business, price: 0.01) }
      order = within_tenant { create(:order, business: business) }

      5.times { OrderCart.add_item(order, product: product, quantity: 200) }

      expect(order.reload.total).to eq(10.0)
    end

    it "stays exact when the total includes a fractional tax and fee" do
      product = within_tenant { create(:product, business: business, price: 19.99) }
      order = within_tenant { create(:order, business: business) }
      within_tenant { order.update!(tax: 0.1, delivery_fee: 2.99) }

      OrderCart.add_item(order, product: product)

      expect(order.reload.total).to eq(23.08)
    end
  end
end
