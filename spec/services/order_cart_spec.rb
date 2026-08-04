require "rails_helper"

RSpec.describe OrderCart do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe ".draft_for" do
    it "finds or creates a draft order for the user's business" do
      order = OrderCart.draft_for(cashier)

      expect(order).to be_draft
      expect(order.business).to eq(business)
      expect(order.user).to eq(cashier)
      expect(OrderCart.draft_for(cashier).id).to eq(order.id)
    end
  end

  describe "#add_item" do
    it "appends a line item with a snapshot" do
      product = within_tenant { create(:product, business: business, price: 9.9) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product)

      item = order.order_items.first
      expect(item.product_name).to eq(product.name)
      expect(item.unit_price).to eq(9.9)
      expect(item.quantity).to eq(1)
      expect(order.reload.total).to eq(9.9)
    end

    it "merges repeated plain adds into a bigger quantity" do
      product = within_tenant { create(:product, business: business) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, quantity: 2)
      OrderCart.add_item(order, product: product, quantity: 3)

      expect(order.order_items.size).to eq(1)
      expect(order.order_items.first.quantity).to eq(5)
      expect(order.reload.total).to eq(50.0)
    end

    it "clamps quantities to at least one" do
      product = within_tenant { create(:product, business: business) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, quantity: 0)

      expect(order.order_items.first.quantity).to eq(1)
    end

    it "refuses products from another business" do
      foreign_product = create(:product)
      order = within_tenant { create(:order, business: business) }

      expect { OrderCart.add_item(order, product: foreign_product) }
        .to raise_error(OrderCart::CartClosedError)
    end

    it "refuses to mutate a confirmed order" do
      product = within_tenant { create(:product, business: business) }
      order = within_tenant { create(:order, :open, business: business) }

      expect { OrderCart.add_item(order, product: product) }
        .to raise_error(OrderCart::CartClosedError)
    end
  end

  describe "#update_quantity" do
    it "changes the quantity and refreshes totals" do
      order = within_tenant do
        create(:order, business: business).tap do |o|
          product = create(:product, business: business, price: 5.0)
          create(:order_item, order: o, product: product, quantity: 2)
        end
      end

      OrderCart.update_quantity(order, order.order_items.first.id, 4)

      expect(order.order_items.first.quantity).to eq(4)
      expect(order.reload.total).to eq(20.0)
    end

    it "removes the line when the quantity drops below one" do
      order = within_tenant do
        create(:order, business: business).tap do |o|
          product = create(:product, business: business, price: 5.0)
          create(:order_item, order: o, product: product, quantity: 2)
        end
      end

      OrderCart.update_quantity(order, order.order_items.first.id, 0)

      expect(order.order_items.reload).to be_empty
      expect(order.reload.total).to eq(0.0)
    end
  end

  describe "#remove_item" do
    it "removes the line and recomputes the order" do
      order = within_tenant do
        create(:order, business: business).tap do |o|
          product = create(:product, business: business, price: 5.0)
          create(:order_item, order: o, product: product, quantity: 2)
        end
      end

      OrderCart.remove_item(order, order.order_items.first.id)

      expect(order.order_items.reload).to be_empty
      expect(order.reload.total).to eq(0.0)
    end
  end
end
