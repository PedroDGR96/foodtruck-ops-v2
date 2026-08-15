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

    it "refuses a variant that belongs to a different product" do
      product = within_tenant { create(:product, business: business) }
      other_product = within_tenant { create(:product, business: business) }
      variant = within_tenant { create(:product_variant, business: business, product: other_product) }
      order = within_tenant { create(:order, business: business) }

      expect { OrderCart.add_item(order, product: product, variant: variant) }
        .to raise_error(OrderCart::CartClosedError, /pertence/)
    end

    it "snapshots addon names and prices when adding with addons" do
      product = within_tenant { create(:product, business: business) }
      group = within_tenant { create(:product_addon_group, business: business, product: product) }
      addon = within_tenant { create(:product_addon, business: business, product_addon_group: group, price: 2.5) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, addons: [ addon ])

      item = order.order_items.first
      expect(item.order_item_addons.size).to eq(1)
      expect(item.order_item_addons.first.name).to eq(addon.name)
      expect(item.order_item_addons.first.price).to eq(2.5)
    end

    it "merges repeated adds with the same addon set" do
      product = within_tenant { create(:product, business: business, price: 10.0) }
      group = within_tenant { create(:product_addon_group, business: business, product: product) }
      addon = within_tenant { create(:product_addon, business: business, product_addon_group: group, price: 2.0) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, addons: [ addon ], quantity: 1)
      OrderCart.add_item(order, product: product, addons: [ addon ], quantity: 2)

      expect(order.order_items.size).to eq(1)
      expect(order.order_items.first.quantity).to eq(3)
    end

    it "keeps different addon sets on separate lines" do
      product = within_tenant { create(:product, business: business, price: 10.0) }
      group = within_tenant { create(:product_addon_group, business: business, product: product) }
      cheese = within_tenant { create(:product_addon, business: business, product_addon_group: group, name: "Queijo", price: 2.0) }
      bacon = within_tenant { create(:product_addon, business: business, product_addon_group: group, name: "Bacon", price: 3.0) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, addons: [ cheese ])
      OrderCart.add_item(order, product: product, addons: [ bacon ])

      expect(order.order_items.size).to eq(2)
    end

    it "keeps a plain add on a separate line from an addon line" do
      product = within_tenant { create(:product, business: business, price: 10.0) }
      group = within_tenant { create(:product_addon_group, business: business, product: product) }
      cheese = within_tenant { create(:product_addon, business: business, product_addon_group: group, name: "Queijo", price: 2.0) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.add_item(order, product: product, addons: [ cheese ])
      OrderCart.add_item(order, product: product)

      expect(order.order_items.size).to eq(2)
      expect(order.order_items.first.quantity).to eq(1)
      expect(order.order_items.last.quantity).to eq(1)
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

  describe "#set_customer" do
    it "attaches a customer from the same business" do
      customer = within_tenant { create(:customer, business: business) }
      order = within_tenant { create(:order, business: business) }

      OrderCart.set_customer(order, customer: customer)

      expect(order.reload.customer).to eq(customer)
    end

    it "refuses a customer from another business" do
      foreign_customer = create(:customer)
      order = within_tenant { create(:order, business: business) }

      expect { OrderCart.set_customer(order, customer: foreign_customer) }
        .to raise_error(OrderCart::CartClosedError)
    end

    it "refuses to attach a customer to a confirmed order" do
      customer = within_tenant { create(:customer, business: business) }
      order = within_tenant { create(:order, :open, business: business) }

      expect { OrderCart.set_customer(order, customer: customer) }
        .to raise_error(OrderCart::CartClosedError)
    end
  end

  describe "#quick_create_customer" do
    it "creates and attaches a customer mid-order" do
      order = within_tenant { create(:order, business: business) }

      OrderCart.quick_create_customer(order, name: "Maria", phone: "(11) 91234-5678")

      expect(order.reload.customer).to be_present
      expect(order.customer.name).to eq("Maria")
      expect(order.customer.phone).to eq("11912345678")
      expect(order.customer.business).to eq(business)
    end

    it "raises when the attributes are invalid" do
      order = within_tenant { create(:order, business: business) }

      expect { OrderCart.quick_create_customer(order, name: "") }
        .to raise_error(ActiveRecord::RecordInvalid)
      expect(order.reload.customer).to be_nil
    end
  end

  describe "#clear_customer" do
    it "detaches the customer from the order" do
      customer = within_tenant { create(:customer, business: business) }
      order = within_tenant { create(:order, business: business, customer: customer) }

      OrderCart.clear_customer(order)

      expect(order.reload.customer).to be_nil
    end
  end
end
