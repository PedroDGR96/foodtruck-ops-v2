# frozen_string_literal: true

require "rails_helper"

RSpec.describe Order do
  let(:business) { create(:business) }

  describe "#recalculate_totals! money math" do
    it "computes subtotal, total and balance from line items" do
      Tenancy.with_business(business) do
        order = create(
          :order,
          business: business,
          status: :paid,
          payment_status: :pending,
          subtotal: 0.0,
          tax: 2.50,
          delivery_fee: 1.00,
          total: 0.0
        )

        item = create(
          :order_item,
          order: order,
          product_name: "Burger",
          quantity: 3,
          unit_price: 10.50,
          line_total: 0.0
        )
        create(:order_item_addon, order_item: item, name: "Extra cheese", price: 2.00)

        order.recalculate_totals!
        order.reload

        # subtotal = (unit_price + addons).round(2) * quantity = (10.50 + 2.00) * 3 = 37.50
        expect(order.subtotal).to eq(37.50)
        # total = subtotal + tax + delivery_fee = 37.50 + 2.50 + 1.00 = 41.00
        expect(order.total).to eq(41.00)

        create(:payment, order: order, status: :succeeded, amount: 41.00)

        Tenancy.with_business(business) do
          expect(order.balance_due).to eq(0.0)
          expect(order.fully_paid?).to be(true)
        end
      end
    end

    it "tracks partial payments via balance_due and fully_paid?" do
      Tenancy.with_business(business) do
        order = create(
          :order,
          business: business,
          status: :paid,
          payment_status: :pending,
          subtotal: 0.0,
          tax: 1.50,
          delivery_fee: 0.0,
          total: 0.0
        )

        item = create(
          :order_item,
          order: order,
          product_name: "Salad",
          quantity: 2,
          unit_price: 8.00,
          line_total: 0.0
        )
        create(:order_item_addon, order_item: item, name: "Extra dressing", price: 1.50)

        order.recalculate_totals!
        order.reload

        # subtotal = (8.00 + 1.50).round(2) * 2 = 9.50 * 2 = 19.00
        expect(order.subtotal).to eq(19.00)
        # total = 19.00 + 1.50 + 0.00 = 20.50
        expect(order.total).to eq(20.50)

        create(:payment, order: order, status: :succeeded, amount: 10.00)

        Tenancy.with_business(business) do
          # balance_due = total - paid_amount = 20.50 - 10.00 = 10.50
          expect(order.balance_due).to eq(10.50)
          expect(order.fully_paid?).to be(false)
        end
      end
    end

    it "sums multiple line items with mixed addons and quantities" do
      Tenancy.with_business(business) do
        order = create(
          :order,
          business: business,
          status: :paid,
          payment_status: :pending,
          subtotal: 0.0,
          tax: 1.25,
          delivery_fee: 3.75,
          total: 0.0
        )

        item_a = create(
          :order_item,
          order: order,
          product_name: "Burger",
          quantity: 2,
          unit_price: 12.00,
          line_total: 0.0
        )
        create(:order_item_addon, order_item: item_a, name: "Extra cheese", price: 1.50)

        item_b = create(
          :order_item,
          order: order,
          product_name: "Fries",
          quantity: 4,
          unit_price: 3.25,
          line_total: 0.0
        )

        order.recalculate_totals!
        order.reload

        # item_a subtotal = (12.00 + 1.50).round(2) * 2 = 13.50 * 2 = 27.00
        # item_b subtotal = (3.25 + 0.00).round(2) * 4 = 3.25 * 4 = 13.00
        # order.subtotal = 27.00 + 13.00 = 40.00
        expect(order.subtotal).to eq(40.00)
        # total = 40.00 + 1.25 + 3.75 = 45.00
        expect(order.total).to eq(45.00)

        create(:payment, order: order, status: :succeeded, amount: 45.00)

        Tenancy.with_business(business) do
          expect(order.balance_due).to eq(0.0)
          expect(order.fully_paid?).to be(true)
        end
      end
    end

    it "computes total from subtotal plus tax and delivery fee without addons" do
      Tenancy.with_business(business) do
        order = create(
          :order,
          business: business,
          status: :paid,
          payment_status: :pending,
          subtotal: 0.0,
          tax: 3.75,
          delivery_fee: 2.50,
          total: 0.0
        )

        create(
          :order_item,
          order: order,
          product_name: "Burger",
          quantity: 2,
          unit_price: 7.50,
          line_total: 0.0
        )

        order.recalculate_totals!
        order.reload

        # subtotal = (7.50 + 0.0).round(2) * 2 = 15.00
        expect(order.subtotal).to eq(15.00)
        # total = 15.00 + 3.75 + 2.50 = 21.25
        expect(order.total).to eq(21.25)

        create(:payment, order: order, status: :succeeded, amount: 21.25)

        Tenancy.with_business(business) do
          expect(order.balance_due).to eq(0.0)
          expect(order.fully_paid?).to be(true)
        end
      end
    end

    it "rounds per-item unit totals to two decimals before multiplying by quantity" do
      Tenancy.with_business(business) do
        order = create(
          :order,
          business: business,
          status: :paid,
          payment_status: :pending,
          subtotal: 0.0,
          tax: 0.50,
          delivery_fee: 1.25,
          total: 0.0
        )

        item = create(
          :order_item,
          order: order,
          product_name: "Special",
          quantity: 3,
          unit_price: 4.33,
          line_total: 0.0
        )
        create(:order_item_addon, order_item: item, name: "Extra topping", price: 1.67)

        order.recalculate_totals!
        order.reload

        # per-item unit = (4.33 + 1.67).round(2) = 6.00; subtotal = 6.00 * 3 = 18.00
        expect(order.subtotal).to eq(18.00)
        # total = 18.00 + 0.50 + 1.25 = 19.75
        expect(order.total).to eq(19.75)

        create(:payment, order: order, status: :succeeded, amount: 19.75)

        Tenancy.with_business(business) do
          expect(order.balance_due).to eq(0.0)
          expect(order.fully_paid?).to be(true)
        end
      end
    end

    it "recomputes totals when an addon is added after the initial recalculation" do
      Tenancy.with_business(business) do
        order = create(
          :order,
          business: business,
          status: :paid,
          payment_status: :pending,
          subtotal: 0.0,
          tax: 1.00,
          delivery_fee: 0.0,
          total: 0.0
        )

        item = create(
          :order_item,
          order: order,
          product_name: "Burger",
          quantity: 2,
          unit_price: 10.00,
          line_total: 0.0
        )

        # First pass: no addons yet -> subtotal = (10.00 + 0).round(2) * 2 = 20.00
        order.recalculate_totals!
        expect(order.reload.subtotal).to eq(20.00)
        expect(order.total).to eq(21.00)

        # Add an addon and recalculate again -> subtotal = (10.00 + 3.50).round(2) * 2 = 27.00
        create(:order_item_addon, order_item: item, name: "Extra cheese", price: 3.50)
        order.recalculate_totals!
        expect(order.reload.subtotal).to eq(27.00)
        # total = 27.00 + 1.00 + 0.00 = 28.00
        expect(order.total).to eq(28.00)

        create(:payment, order: order, status: :succeeded, amount: 28.00)

        Tenancy.with_business(business) do
          expect(order.balance_due).to eq(0.0)
          expect(order.fully_paid?).to be(true)
        end
      end
    end

    it "sums multiple successful payments against the order total" do
      Tenancy.with_business(business) do
        order = create(
          :order,
          business: business,
          status: :paid,
          payment_status: :pending,
          subtotal: 0.0,
          tax: 1.25,
          delivery_fee: 3.75,
          total: 0.0
        )

        item = create(
          :order_item,
          order: order,
          product_name: "Taco",
          quantity: 5,
          unit_price: 4.00,
          line_total: 0.0
        )

        order.recalculate_totals!
        order.reload

        # subtotal = (4.00 + 0.0).round(2) * 5 = 20.00
        expect(order.subtotal).to eq(20.00)
        # total = 20.00 + 1.25 + 3.75 = 25.00
        expect(order.total).to eq(25.00)

        create(:payment, order: order, status: :succeeded, amount: 10.00)
        create(:payment, order: order, status: :succeeded, amount: 15.00)

        Tenancy.with_business(business) do
          # paid_amount = 10.00 + 15.00 = 25.00
          expect(order.paid_amount).to eq(25.00)
          # balance_due = total - paid_amount = 25.00 - 25.00 = 0.00
          expect(order.balance_due).to eq(0.00)
          expect(order.fully_paid?).to be(true)
        end
      end
    end

    it "computes correct totals when every line item has its own distinct addon" do
      Tenancy.with_business(business) do
        order = create(
          :order,
          business: business,
          status: :paid,
          payment_status: :pending,
          subtotal: 0.0,
          tax: 2.00,
          delivery_fee: 1.50,
          total: 0.0
        )

        item_a = create(
          :order_item,
          order: order,
          product_name: "Burger",
          quantity: 3,
          unit_price: 9.00,
          line_total: 0.0
        )
        create(:order_item_addon, order_item: item_a, name: "Extra cheese", price: 1.50)

        item_b = create(
          :order_item,
          order: order,
          product_name: "Fries",
          quantity: 2,
          unit_price: 6.00,
          line_total: 0.0
        )
        create(:order_item_addon, order_item: item_b, name: "Extra sauce", price: 1.00)

        order.recalculate_totals!
        order.reload

        # item_a subtotal = (9.00 + 1.50).round(2) * 3 = 10.50 * 3 = 31.50
        # item_b subtotal = (6.00 + 1.00).round(2) * 2 = 7.00 * 2 = 14.00
        # order.subtotal = 31.50 + 14.00 = 45.50
        expect(order.subtotal).to eq(45.50)
        # total = 45.50 + 2.00 + 1.50 = 49.00
        expect(order.total).to eq(49.00)

        create(:payment, order: order, status: :succeeded, amount: 49.00)

        Tenancy.with_business(business) do
          expect(order.balance_due).to eq(0.0)
          expect(order.fully_paid?).to be(true)
        end
      end
    end

    it "computes total as subtotal plus tax plus delivery fee for a single item without addons" do
      Tenancy.with_business(business) do
        order = create(
          :order,
          business: business,
          status: :paid,
          payment_status: :pending,
          subtotal: 0.0,
          tax: 5.25,
          delivery_fee: 4.75,
          total: 0.0
        )

        item = create(
          :order_item,
          order: order,
          product_name: "Coffee",
          quantity: 1,
          unit_price: 6.00,
          line_total: 0.0
        )

        order.recalculate_totals!
        order.reload

        # subtotal = (6.00 + 0).round(2) * 1 = 6.00
        expect(order.subtotal).to eq(6.00)
        # total = 6.00 + 5.25 + 4.75 = 16.00
        expect(order.total).to eq(16.00)

        create(:payment, order: order, status: :succeeded, amount: 16.00)

        Tenancy.with_business(business) do
          # paid_amount = 16.00
          expect(order.paid_amount).to eq(16.00)
          # balance_due = total - paid_amount = 16.00 - 16.00 = 0.00
          expect(order.balance_due).to eq(0.00)
          expect(order.fully_paid?).to be(true)
        end
      end
    end
  end
end
