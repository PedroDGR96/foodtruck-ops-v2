require "rails_helper"

RSpec.describe "Point of Sale", type: :request do
  let(:business) { create(:business) }
  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  def product
    @product ||= Tenancy.with_business(business) do
      category = create(:category, business: business)
      create(:product, business: business, category: category, price: 12.5)
    end
  end

  describe "access" do
    it "lets owners and cashiers open the POS" do
      [ owner, cashier ].each do |user|
        login_as user, scope: :user
        get "/pos"
        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end

    it "forbids kitchen staff from the POS" do
      login_as kitchen, scope: :user
      get "/pos"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "cart" do
    before { login_as cashier, scope: :user }

    it "adds a product to the draft order" do
      product

      expect { post "/pos/cart", params: { product_id: product.id, quantity: 2 } }
        .to change { Tenancy.with_business(business) { Order.count } }.by(1)

      order = Tenancy.with_business(business) { Order.last }
      expect(order).to be_draft
      expect(Tenancy.with_business(business) { order.order_items.first.quantity }).to eq(2)
      expect(order.total).to eq(25.0)
    end

    it "updates the quantity of an existing line" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }
      order = Tenancy.with_business(business) { Order.last }
      item_id = Tenancy.with_business(business) { order.order_items.first.id }

      patch "/pos/cart/#{item_id}", params: { quantity: 3 }

      expect(Tenancy.with_business(business) { order.order_items.first.quantity }).to eq(3)
    end

    it "removes a line item" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }
      order = Tenancy.with_business(business) { Order.last }
      item_id = Tenancy.with_business(business) { order.order_items.first.id }

      delete "/pos/cart/#{item_id}"

      expect(Tenancy.with_business(business) { order.order_items.empty? }).to be(true)
    end
  end

  describe "confirmation" do
    before { login_as cashier, scope: :user }

    it "confirms a non-empty cart and redirects to payment" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }
      order = Tenancy.with_business(business) { Order.last }

      post "/pos/confirm", params: { order: { order_type: "local" } }

      expect(response).to redirect_to(new_order_payment_path(order))
      expect(Tenancy.with_business(business) { order.reload }).to be_open
      expect(Tenancy.with_business(business) { order.order_events.last.event }).to eq("confirmed")
    end
    it "refuses to confirm an empty cart" do
      post "/pos/confirm"

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "customer on the cart" do
    before { login_as cashier, scope: :user }

    it "attaches an existing customer to the draft order" do
      cust = Tenancy.with_business(business) { create(:customer, business: business, name: "Maria Silva") }

      post "/pos/customer", params: { customer_id: cust.id }

      expect(response).to redirect_to(pos_path)
      expect(flash[:notice]).to include("Maria Silva")
      order = Tenancy.with_business(business) { Order.last }
      expect(Tenancy.with_business(business) { order.reload.customer_id }).to eq(cust.id)
    end

    it "quick-creates a customer mid-order" do
      post "/pos/customer", params: { customer: { name: "João Souza", phone: "(11) 98877-6655" } }

      expect(response).to redirect_to(pos_path)
      cust = Tenancy.with_business(business) { Customer.find_by(name: "João Souza") }
      expect(Tenancy.with_business(business) { cust.phone }).to eq("11988776655")
      order = Tenancy.with_business(business) { Order.last }
      expect(Tenancy.with_business(business) { order.reload.customer_id }).to eq(cust.id)
    end

    it "refuses an invalid quick-create" do
      post "/pos/customer", params: { customer: { name: "" } }

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to be_present
      expect(Tenancy.with_business(business) { Customer.count }).to eq(0)
    end

    it "removes the customer from the cart" do
      cust = Tenancy.with_business(business) { create(:customer, business: business, name: "Maria Silva") }
      post "/pos/customer", params: { customer_id: cust.id }
      order = Tenancy.with_business(business) { Order.last }

      delete "/pos/customer"

      expect(Tenancy.with_business(business) { order.reload.customer_id }).to be_nil
    end
  end
end
