require "rails_helper"

RSpec.describe "Daily Reports", type: :request do
  let(:business) { create(:business, timezone: "America/Sao_Paulo") }
  let(:zone) { ActiveSupport::TimeZone["America/Sao_Paulo"] }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  def create_paid_order(business, total:, created_at:)
    order = create(:order, business: business, subtotal: total, tax: 0, delivery_fee: 0, total: total,
                           created_at: created_at)
    yield order if block_given?
    order.update!(status: "paid", payment_status: "paid")
    order
  end

  def login(role)
    user = staff(role)
    login_as user, scope: :user
    user
  end

  after { logout(:user) }

  describe "GET /daily_report" do
    it "allows owner to view the daily report" do
      login(:owner)

      get daily_report_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Relatório diário")
    end

    it "forbids cashier from viewing the daily report" do
      login(:cashier)

      get daily_report_path

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids kitchen from viewing the daily report" do
      login(:kitchen)

      get daily_report_path

      expect(response).to have_http_status(:forbidden)
    end

    it "displays report totals matching order data" do
      cashier = login(:owner)

      Tenancy.with_business(business) do
        product = create(:product, business: business, name: "Burger", price: 25.0)
        create_paid_order(business, total: 50.0, created_at: zone.local(2026, 8, 4, 12, 0)) do |order|
          create(:order_item, order: order, product: product, product_name: "Burger", unit_price: 25.0,
                               quantity: 2, line_total: 50.0)
          create(:payment, order: order, amount: 50.0, method: "cash", status: "succeeded")
        end
      end

      get daily_report_path(date: "2026-08-04")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("R$ 50,00")
      expect(response.body).to include("Burger")
      expect(response.body).to include("Dinheiro")
    end

    it "displays zeroed data for a day with no orders" do
      login(:owner)

      get daily_report_path(date: "2026-08-04")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nenhum pedido registrado neste dia.")
    end

    it "accepts a date parameter to view a specific day" do
      login(:owner)

      Tenancy.with_business(business) do
        create_paid_order(business, total: 100.0, created_at: zone.local(2026, 7, 15, 10, 0)) do |order|
          create(:payment, order: order, amount: 100.0, method: "cash", status: "succeeded")
        end
      end

      get daily_report_path(date: "2026-07-15")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("R$ 100,00")
    end

    it "shows date navigation links" do
      login(:owner)

      get daily_report_path(date: "2026-08-04")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("aria-label=\"Dia anterior\"")
      expect(response.body).to include("aria-label=\"Próximo dia\"")
      expect(response.body).to include("date=2026-08-03")
      expect(response.body).to include("date=2026-08-05")
    end
  end
end
