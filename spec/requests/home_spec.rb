require "rails_helper"

RSpec.describe "Home dashboard", type: :request do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def create_paid_order(total:)
    Tenancy.with_business(business) do
      order = create(:order, :open, business: business, total: total, subtotal: total)
      create(:payment, order: order, amount: total)
      order.update!(status: :paid, payment_status: :paid)
    end
  end

  describe "GET /" do
    it "shows today's stats to every staff role" do
      create_paid_order(total: 30.0)

      [ owner, cashier, kitchen ].each do |user|
        login_as user, scope: :user
        get "/"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Faturamento de hoje")
        expect(response.body).to include("R$ 30,00")
        expect(response.body).to include("Pedidos de hoje")
        logout(:user)
      end
    end

    it "excludes open orders from the active count" do
      create_paid_order(total: 30.0)
      Tenancy.with_business(business) do
        create(:order, :open, business: business, total: 20.0, subtotal: 20.0)
      end

      login_as owner, scope: :user
      get "/"

      expect(response.body).to match(%r{Pedidos em andamento</dt>\s*<dd class="text-xl font-bold">1</dd>})
      expect(response.body).to match(%r{Pedidos de hoje</dt>\s*<dd class="text-xl font-bold">2</dd>})
    end

    it "shows the kitchen queue to kitchen staff" do
      create_paid_order(total: 30.0)

      login_as kitchen, scope: :user
      get "/"

      expect(response.body).to include("Fila da cozinha")
      expect(response.body).to match(%r{Fila da cozinha</dt>\s*<dd class="text-xl font-bold">1</dd>})
    end

    it "prompts a cashier to open a shift when none is open" do
      login_as cashier, scope: :user
      get "/"

      expect(response.body).to include("Você não tem um turno de caixa aberto")
      expect(response.body).to include("Abrir turno")
    end

    it "shows the open shift for a cashier with one" do
      Tenancy.with_business(business) do
        create(:cash_register, business: business, user: cashier)
      end

      login_as cashier, scope: :user
      get "/"

      expect(response.body).to include("Turno de caixa aberto desde")
    end
  end
end
