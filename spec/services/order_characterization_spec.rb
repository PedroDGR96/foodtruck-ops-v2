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
  end
end
