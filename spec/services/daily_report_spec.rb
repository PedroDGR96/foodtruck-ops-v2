require "rails_helper"

RSpec.describe DailyReport do
  let(:business) { create(:business, timezone: "America/Sao_Paulo") }

  def with_business(&block)
    Tenancy.with_business(business, &block)
  end

  describe ".call" do
    let(:date) { Date.new(2026, 8, 4) }
    let(:zone) { ActiveSupport::TimeZone["America/Sao_Paulo"] }
    let(:window) { BusinessDay.window(business, date) }

    it "returns zeroed data when no orders exist" do
      report = with_business { described_class.call(business, date) }

      expect(report[:total_count]).to eq(0)
      expect(report[:gross_total]).to eq(0.0)
      expect(report[:refund_total]).to eq(0.0)
      expect(report[:by_method]).to eq({})
      expect(report[:by_product]).to eq([])
      expect(report[:date]).to eq(date)
    end

    it "aggregates sales by payment method" do
      order = with_business do
        o = create(:order, :paid, business: business, total: 50.0, subtotal: 50.0, tax: 0, delivery_fee: 0,
                                    created_at: zone.local(2026, 8, 4, 12, 0))
        create(:payment, order: o, amount: 30.0, method: "cash", status: "succeeded")
        create(:payment, order: o, amount: 20.0, method: "pix", status: "succeeded")
        o
      end

      report = with_business { described_class.call(business, date) }

      expect(report[:by_method]).to eq({ "cash" => 30.0, "pix" => 20.0 })
    end

    it "aggregates sales by product" do
      with_business do
        o = create(:order, :paid, business: business, total: 60.0, subtotal: 60.0, tax: 0, delivery_fee: 0,
                                    created_at: zone.local(2026, 8, 4, 10, 0))
        product = create(:product, business: business, name: "Burger", price: 25.0)
        create(:order_item, order: o, product: product, product_name: "Burger", unit_price: 25.0, quantity: 2, line_total: 50.0)
        create(:order_item, order: o, product: product, product_name: "Fries", unit_price: 10.0, quantity: 1, line_total: 10.0)
        create(:payment, order: o, amount: 60.0, method: "card", status: "succeeded")
      end

      report = with_business { described_class.call(business, date) }

      products = report[:by_product]
      expect(products.length).to eq(2)
      expect(products.first.product_name).to eq("Burger")
      expect(products.first.quantity).to eq(2)
      expect(products.first.total).to eq(50.0)
      expect(products.last.product_name).to eq("Fries")
      expect(products.last.quantity).to eq(1)
      expect(products.last.total).to eq(10.0)
    end

    it "nets refunds against gross total" do
      with_business do
        paid_order = create(:order, :paid, business: business, total: 100.0, subtotal: 100.0, tax: 0, delivery_fee: 0,
                                            created_at: zone.local(2026, 8, 4, 11, 0))
        create(:payment, order: paid_order, amount: 100.0, method: "cash", status: "succeeded")

        refunded_order = create(:order, :refunded, business: business, total: 30.0, subtotal: 30.0, tax: 0, delivery_fee: 0,
                                            created_at: zone.local(2026, 8, 4, 14, 0))
      end

      report = with_business { described_class.call(business, date) }

      expect(report[:total_count]).to eq(1)
      expect(report[:gross_total]).to eq(100.0)
      expect(report[:refund_total]).to eq(30.0)
    end

    it "honors the business timezone for day boundaries" do
      zone = ActiveSupport::TimeZone["America/Sao_Paulo"]
      sao_paulo = create(:business, timezone: "America/Sao_Paulo")

      Tenancy.with_business(sao_paulo) do
        create(:order, :paid, business: sao_paulo, total: 100.0, subtotal: 100.0, tax: 0, delivery_fee: 0,
                                created_at: zone.local(2026, 8, 4, 23, 30))
      end

      report_tuesday = nil
      report_wednesday = nil

      Tenancy.with_business(sao_paulo) do
        report_tuesday = described_class.call(sao_paulo, Date.new(2026, 8, 4))
        report_wednesday = described_class.call(sao_paulo, Date.new(2026, 8, 5))
      end

      expect(report_tuesday[:total_count]).to eq(1)
      expect(report_tuesday[:gross_total]).to eq(100.0)
      expect(report_wednesday[:total_count]).to eq(0)
    end

    it "includes shifts that overlap the day window" do
      Tenancy.with_business(business) do
        cashier = create(:user, :cashier, business: business)

        shift = create(:cash_register, :open, business: business, user: cashier,
                       opened_at: zone.local(2026, 8, 4, 9, 0))

        report = described_class.call(business, date)

        # Compare IDs — the report contains model instances.
        expect(report[:shifts].pluck(:id)).to include(shift.id)
      end
    end

    it "excludes orders outside the day window" do
      with_business do
        create(:order, :paid, business: business, total: 100.0, subtotal: 100.0, tax: 0, delivery_fee: 0,
                                created_at: zone.local(2026, 8, 3, 23, 59))
      end

      report = with_business { described_class.call(business, date) }

      expect(report[:total_count]).to eq(0)
    end

    it "excludes draft and cancelled orders from purchases" do
      with_business do
        create(:order, :paid, business: business, total: 100.0, subtotal: 100.0, tax: 0, delivery_fee: 0,
                                created_at: zone.local(2026, 8, 4, 10, 0))
        create(:order, business: business, total: 50.0, subtotal: 50.0, tax: 0, delivery_fee: 0,
                        created_at: zone.local(2026, 8, 4, 11, 0))
        create(:order, :cancelled, business: business, total: 25.0, subtotal: 25.0, tax: 0, delivery_fee: 0,
                                    created_at: zone.local(2026, 8, 4, 12, 0))
      end

      report = with_business { described_class.call(business, date) }

      expect(report[:total_count]).to eq(1)
      expect(report[:gross_total]).to eq(100.0)
    end

    it "sorts products by total descending" do
      with_business do
        o = create(:order, :paid, business: business, total: 60.0, subtotal: 60.0, tax: 0, delivery_fee: 0,
                                    created_at: zone.local(2026, 8, 4, 10, 0))
        product = create(:product, business: business, name: "A", price: 10.0)
        create(:order_item, order: o, product: product, product_name: "Cheap", unit_price: 5.0, quantity: 1, line_total: 5.0)
        create(:order_item, order: o, product: product, product_name: "Expensive", unit_price: 55.0, quantity: 1, line_total: 55.0)
        create(:payment, order: o, amount: 60.0, method: "cash", status: "succeeded")
      end

      report = with_business { described_class.call(business, date) }

      expect(report[:by_product].first.product_name).to eq("Expensive")
      expect(report[:by_product].last.product_name).to eq("Cheap")
    end
  end
end
