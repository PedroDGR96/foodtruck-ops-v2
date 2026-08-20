require "rails_helper"

RSpec.describe Order do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "tenancy" do
    it "is scoped to the current business" do
      other = create(:business)
      order = within_tenant { create(:order, business: business) }

      Tenancy.with_business(other) { expect(Order.pluck(:id)).to be_empty }
      Tenancy.with_business(business) { expect(Order.pluck(:id)).to eq([ order.id ]) }
    end
  end

  describe "statuses" do
    it "defaults to draft with pending payment and kitchen statuses" do
      order = within_tenant { create(:order, business: business) }

      expect(order).to be_draft
      expect(order).to be_pending_payment
      expect(order.kitchen_status).to eq("pending")
      expect(order.payment_status).to eq("pending")
    end

    it "exposes the order type enum" do
      order = within_tenant { create(:order, order_type: "pickup", business: business) }

      expect(order).to be_pickup
    end
  end

  describe "money aggregates" do
    it "computes the paid amount from succeeded payments only" do
      order = within_tenant do
        create(:order, :open, business: business, total: 30.0, subtotal: 30.0).tap do |o|
          create(:payment, order: o, amount: 20.0)
          create(:payment, order: o, amount: 5.0, status: "refunded")
        end
      end

      expect(order.paid_amount).to eq(20.0)
    end

    it "computes the balance due against the total" do
      order = within_tenant do
        create(:order, :open, business: business, total: 50.0, subtotal: 50.0).tap do |o|
          create(:payment, order: o, amount: 15.0)
        end
      end

      expect(order.balance_due).to eq(35.0)
      expect(order).not_to be_fully_paid
    end

    it "is fully paid when payments reach the total" do
      order = within_tenant do
        create(:order, :open, business: business, total: 50.0, subtotal: 50.0).tap do |o|
          create(:payment, order: o, amount: 50.0)
        end
      end

      expect(order).to be_fully_paid
      expect(order.balance_due).to eq(0.0)
    end
  end

  describe "validations" do
    it "rejects a total inconsistent with subtotal plus tax" do
      order = within_tenant { build(:order, business: business, subtotal: 10.0, tax: 2.0, total: 13.0) }

      expect(order).not_to be_valid
      expect(order.errors[:total]).to include("não confere com subtotal e impostos")
    end

    it "accepts a consistent total" do
      order = within_tenant { build(:order, business: business, subtotal: 10.0, tax: 2.0, total: 12.0) }

      expect(order).to be_valid
    end

    it "rejects a negative total" do
      order = within_tenant { build(:order, business: business, subtotal: -1.0) }

      expect(order).not_to be_valid
    end

    it "rejects a paid status where payments do not cover the total" do
      order = within_tenant do
        o = create(:order, business: business, status: "paid", payment_status: "paid", total: 30.0)
        create(:payment, order: o, amount: 10.0, status: "succeeded")
        o.reload
      end

      expect(order).not_to be_valid
      expect(order.errors[:payment_status]).to include("não confere com o total pago")
    end
  end

  describe "scopes" do
    it "lists recent orders newest first" do
      first = within_tenant { create(:order, business: business) }
      second = within_tenant { create(:order, business: business) }

      expect(within_tenant { Order.recent.pluck(:id) }).to eq([ second.id, first.id ])
    end

    it "lists active paid/in_kitchen/ready orders" do
      paid = within_tenant { create(:order, :paid, business: business) }
      in_kitchen = within_tenant { create(:order, :in_kitchen, business: business) }
      draft = within_tenant { create(:order, business: business) }

      expect(within_tenant { Order.active.pluck(:id) }).to contain_exactly(paid.id, in_kitchen.id)
      expect(within_tenant { Order.active.pluck(:id) }).not_to include(draft.id)
    end
  end

  describe "customer" do
    it "accepts a customer from the same business" do
      customer = within_tenant { create(:customer, business: business) }

      expect(within_tenant { build(:order, business: business, customer: customer) }).to be_valid
    end

    it "rejects a customer from another business" do
      other = create(:business)
      foreign_customer = Tenancy.with_business(other) { create(:customer, business: other) }

      Tenancy.with_business(business) do
        order = build(:order, business: business, customer: foreign_customer)
        expect(order).not_to be_valid
        expect(order.errors[:customer]).to be_present
      end
    end
  end

  describe "purchases scope" do
    it "includes purchase-flow orders and excludes drafts, cancellations and refunds" do
      paid = within_tenant do
        create(:order, :open, business: business, total: 10.0, subtotal: 10.0).tap do |o|
          create(:payment, order: o, amount: 10.0)
          o.update!(status: :paid, payment_status: :paid)
        end
      end
      open = within_tenant { create(:order, :open, business: business, total: 10.0, subtotal: 10.0) }
      draft = within_tenant { create(:order, business: business) }
      cancelled = within_tenant { create(:order, :cancelled, business: business, total: 10.0, subtotal: 10.0) }

      expect(within_tenant { Order.purchases.pluck(:id) }).to contain_exactly(paid.id, open.id)
      expect(within_tenant { Order.purchases.pluck(:id) }).not_to include(draft.id, cancelled.id)
    end
  end

  describe "delivery" do
    it "requires a delivery address when order_type is delivery" do
      order = within_tenant { build(:order, :delivery, business: business, total: 5.0, subtotal: 0.0) }

      expect(order).not_to be_valid
      expect(order.errors[:delivery_address]).to be_present
    end

    it "is valid for delivery with an address" do
      order = within_tenant do
        build(:order, :delivery, business: business, total: 5.0, subtotal: 0.0).tap do |o|
          o.build_delivery_address(street: "Rua X", city: "São Paulo", state: "SP")
        end
      end

      expect(order).to be_valid
    end

    it "does not require an address for local orders" do
      order = within_tenant { build(:order, business: business, total: 10.0, subtotal: 10.0) }

      expect(order).to be_valid
    end

    it "rejects a total inconsistent with subtotal plus tax plus delivery_fee" do
      order = within_tenant do
        build(:order, :delivery, business: business, subtotal: 10.0, tax: 2.0, delivery_fee: 5.0, total: 20.0).tap do |o|
          o.build_delivery_address(street: "Rua X", city: "São Paulo", state: "SP")
        end
      end

      expect(order).not_to be_valid
      expect(order.errors[:total]).to include("não confere com subtotal e impostos")
    end

    it "accepts a total consistent with subtotal plus tax plus delivery_fee" do
      order = within_tenant do
        build(:order, :delivery, business: business, subtotal: 10.0, tax: 2.0, delivery_fee: 5.0, total: 17.0).tap do |o|
          o.build_delivery_address(street: "Rua X", city: "São Paulo", state: "SP")
        end
      end

      expect(order).to be_valid
    end
  end

  describe "totals recalculation" do
    it "recomputes subtotal and total from line items" do
      order = within_tenant do
        create(:order, business: business).tap do |o|
          product = create(:product, business: business, price: 10.0)
          create(:order_item, order: o, product: product, quantity: 2, unit_price: 10.0)
          o.update!(tax: 5.0)
        end
      end

      order.recalculate_totals!

      expect(order.subtotal).to eq(20.0)
      expect(order.total).to eq(25.0)
    end

    it "includes add-ons in the recalculation" do
      order = within_tenant do
        create(:order, business: business).tap do |o|
          product = create(:product, business: business, price: 10.0)
          item = create(:order_item, order: o, product: product, quantity: 1, unit_price: 10.0)
          create(:order_item_addon, order_item: item, price: 3.0)
        end
      end

      order.recalculate_totals!

      expect(order.subtotal).to eq(13.0)
      expect(order.total).to eq(13.0)
    end
  end
end
