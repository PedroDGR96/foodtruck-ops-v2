require "rails_helper"

RSpec.describe "Customers", type: :request do
  let(:business) { create(:business) }
  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  def customer(attrs = {})
    Tenancy.with_business(business) { create(:customer, business: business, **attrs) }
  end

  describe "listing and search" do
    it "lets every staff role see the customer list" do
      [ owner, cashier, kitchen ].each do |user|
        login_as user, scope: :user
        get "/customers"
        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end

    it "searches customers by name and phone" do
      login_as cashier, scope: :user
      customer(name: "Maria Silva", phone: "11912345678")
      customer(name: "João Souza", phone: "11987654321")

      get "/customers", params: { query: "maria" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maria Silva")
      expect(response.body).not_to include("João Souza")
    end

    it "hides customers from other businesses" do
      login_as cashier, scope: :user
      foreign_business = create(:business)
      foreign = Tenancy.with_business(foreign_business) { create(:customer, business: foreign_business) }

      expect { get "/customers/#{foreign.id}" }.not_to raise_error
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "profile" do
    it "shows purchase history with totals" do
      login_as cashier, scope: :user
      cust = customer(name: "Maria Silva")
      Tenancy.with_business(business) do
        order = create(:order, :open, business: business, customer: cust, total: 30.0, subtotal: 30.0)
        create(:payment, order: order, amount: 30.0)
        order.update!(status: :paid, payment_status: :paid)
      end

      get "/customers/#{cust.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maria Silva")
      expect(response.body).to include("Histórico de compras")
      expect(response.body).to include("R$ 30,00")
      expect(response.body).to include("Pedido")
    end
  end

  describe "creating and editing" do
    before { login_as cashier, scope: :user }

    it "creates, normalizes the phone, shows, edits and discards a customer" do
      get "/customers/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Novo cliente")

      post "/customers", params: { customer: { name: "João Souza", phone: "(11) 98877-6655" } }
      created = Tenancy.with_business(business) { Customer.find_by(name: "João Souza") }
      expect(response).to redirect_to(customer_path(created))
      expect(Tenancy.with_business(business) { created.phone }).to eq("11988776655")

      get "/customers/#{created.id}"
      expect(response).to have_http_status(:ok)

      get edit_customer_path(created)
      expect(response).to have_http_status(:ok)

      patch customer_path(created), params: { customer: { name: "João Souza Filho", whatsapp: "+55 11 98877-6655" } }
      expect(response).to redirect_to(customer_path(created))
      expect(Tenancy.with_business(business) { created.reload.name }).to eq("João Souza Filho")
      expect(Tenancy.with_business(business) { created.reload.whatsapp }).to eq("11988776655")

      login_as owner, scope: :user
      delete customer_path(created)
      expect(response).to redirect_to(customers_path)
      expect(Tenancy.with_business(business) { created.reload.discarded? }).to be(true)
    end

    it "re-renders new and edit on invalid submissions" do
      post "/customers", params: { customer: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Novo cliente")

      target = customer(name: "Maria")
      patch customer_path(target), params: { customer: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Editar cliente")
    end
  end

  describe "authorization" do
    it "forbids kitchen from creating customers" do
      login_as kitchen, scope: :user
      get "/customers/new"
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids cashier from discarding customers" do
      login_as cashier, scope: :user
      cust = customer(name: "Maria")

      delete "/customers/#{cust.id}"

      expect(response).to have_http_status(:forbidden)
      expect(Tenancy.with_business(business) { cust.reload.discarded? }).to be(false)
    end

    it "lets the owner discard a customer" do
      login_as owner, scope: :user
      cust = customer(name: "Maria")

      delete "/customers/#{cust.id}"

      expect(response).to redirect_to(customers_path)
      expect(Tenancy.with_business(business) { cust.reload.discarded? }).to be(true)
    end

    it "forbids guests from accessing the registry" do
      logout
      get "/customers"
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows order count and total spent for customers with orders" do
      login_as cashier, scope: :user
      Tenancy.with_business(business) do
        c = customer(name: "Alice", phone: "11999990001")
        o = create(:order, :open, business: business, customer: c, total: 40.0, subtotal: 40.0)
        create(:payment, order: o, amount: 40.0)
        o.update!(status: "paid", payment_status: "paid")
        customer(name: "Bob", phone: "11999990002")
      end

      get "/customers"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1 ordens · R$ 40,00")
    end
  end
end
