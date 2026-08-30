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
  end
end
