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

    it "redirects with an alert when the product does not exist" do
      post "/pos/cart", params: { product_id: 0, quantity: 1 }

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to eq(I18n.t("pos.product_not_found"))
      order = Tenancy.with_business(business) { Order.last }
      expect(Tenancy.with_business(business) { order.order_items.size }).to eq(0)
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

    it "redirects with an alert when updating a line that does not exist" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }

      patch "/pos/cart/0", params: { quantity: 3 }

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to eq(I18n.t("pos.item_not_found"))
    end

    it "redirects with an alert when removing a line that does not exist" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }

      delete "/pos/cart/0"

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to eq(I18n.t("pos.item_not_found"))
    end

    it "degrades gracefully when the cart is closed mid-operation" do
      product
      allow(OrderCart).to receive(:add_item).and_raise(OrderCart::CartClosedError, "fechado")
      allow(OrderCart).to receive(:update_quantity).and_raise(OrderCart::CartClosedError, "fechado")
      allow(OrderCart).to receive(:remove_item).and_raise(OrderCart::CartClosedError, "fechado")

      post "/pos/cart", params: { product_id: product.id, quantity: 1 }
      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to eq("fechado")

      patch "/pos/cart/#{Tenancy.with_business(business) { product.id }}", params: { quantity: 3 }
      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to eq("fechado")

      delete "/pos/cart/#{Tenancy.with_business(business) { product.id }}"
      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to eq("fechado")
    end

    it "degrades gracefully when the item cannot be saved" do
      product
      invalid = Tenancy.with_business(business) do
        item = OrderItem.new(order: Order.last, product_name: "", unit_price: -1, quantity: 0)
        item.valid?
        item
      end
      allow(OrderCart).to receive(:add_item).and_raise(ActiveRecord::RecordInvalid, invalid)

      post "/pos/cart", params: { product_id: product.id, quantity: 1 }

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to be_present
    end

    it "eager-loads cart items and addons so rendering the POS is not N+1" do
      product
      small = select_count { get "/pos" }

      group = Tenancy.with_business(business) do
        create(:product_addon_group, business: business, product: product)
      end
      addons = Tenancy.with_business(business) do
        create_list(:product_addon, 3, business: business, product_addon_group: group)
      end
      addons.each do |addon|
        post "/pos/cart", params: { product_id: product.id, quantity: 1, addon_ids: [ addon.id ] }
      end
      big = select_count { get "/pos" }

      expect(response).to have_http_status(:ok)
      expect(big - small).to be <= 4
    end
  end

  describe "confirmation" do
    before do
      login_as cashier, scope: :user
      Tenancy.with_business(business) { create(:cash_register, :open, user: cashier, business: business) }
    end

    it "confirms a non-empty cart and redirects to payment" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }
      order = Tenancy.with_business(business) { Order.last }

      post "/pos/confirm", params: { order: { order_type: "local" } }

      expect(response).to redirect_to(checkout_path(order))
      expect(Tenancy.with_business(business) { order.reload }).to be_open
      expect(Tenancy.with_business(business) { order.order_events.last.event }).to eq("confirmed")
    end
    it "refuses to confirm an empty cart" do
      post "/pos/confirm"

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to be_present
    end

    it "refuses to confirm without an open shift" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }

      Tenancy.with_business(business) { CashRegister.open.update_all(status: :closed) }

      post "/pos/confirm", params: { order: { order_type: "local" } }

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to eq(I18n.t("pos.shift_required"))
    end

    it "confirms a delivery order with an address and creates a delivery record" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }
      order = Tenancy.with_business(business) { Order.last }

      Tenancy.with_business(business) do
        business.update!(delivery_fee: 7.0)
        order.update!(delivery_fee: 7.0, total: 19.5)
      end

      post "/pos/confirm", params: {
        order: {
          order_type: "delivery",
          delivery_address: { street: "Rua A", number: "10", neighborhood: "Centro", city: "São Paulo", state: "SP" }
        }
      }

      expect(response).to redirect_to(checkout_path(order))
      Tenancy.with_business(business) do
        order.reload
        expect(order).to be_open
        expect(order).to be_delivery
        expect(order.delivery_fee).to eq(7.0)
        expect(order.delivery_address).to be_present
        expect(order.delivery_address.street).to eq("Rua A")
        expect(order.delivery).to be_present
        expect(order.delivery).to be_pending
      end
    end

    it "refuses to confirm a delivery without an address" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }

      post "/pos/confirm", params: { order: { order_type: "delivery" } }

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to be_present
    end

    it "refuses to confirm a delivery with an incomplete address" do
      product
      post "/pos/cart", params: { product_id: product.id, quantity: 1 }

      post "/pos/confirm", params: {
        order: {
          order_type: "delivery",
          delivery_address: { street: "Rua A" }
        }
      }

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

    it "redirects with an alert when the customer does not exist" do
      post "/pos/customer", params: { customer_id: 0 }

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to eq(I18n.t("pos.customer_not_found"))
    end

    it "degrades gracefully when attaching a customer fails" do
      cust = Tenancy.with_business(business) { create(:customer, business: business, name: "Maria Silva") }
      allow(OrderCart).to receive(:set_customer).and_raise(OrderCart::CartClosedError, "fechado")

      post "/pos/customer", params: { customer_id: cust.id }

      expect(response).to redirect_to(pos_path)
      expect(flash[:alert]).to eq("fechado")
    end
  end
end
