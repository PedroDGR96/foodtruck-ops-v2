require "rails_helper"

RSpec.describe "Orders", type: :request do
  let(:business) { create(:business) }
  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  def order(attrs = {})
    @order ||= Tenancy.with_business(business) { create(:order, business: business, **attrs) }
  end

  def delivery_order(business)
    Tenancy.with_business(business) do
      order = build(:order, :delivery, business: business)
      order.build_delivery_address(
        street: "Rua X", number: "1", neighborhood: "Centro", city: "São Paulo", state: "SP"
      )
      order.save!
      order
    end
  end

  def paid_order(status:, total:)
    Tenancy.with_business(business) do
      o = create(:order, :open, business: business, total: total, subtotal: total)
      create(:payment, order: o, amount: total)
      o.update!(status: status, payment_status: :paid)
      o.update!(kitchen_status: :in_progress) if status == "in_kitchen"
      o
    end
  end

  describe "listing and details" do
    it "lets every staff role see the order list" do
      [ owner, cashier, kitchen ].each do |user|
        login_as user, scope: :user
        get "/orders"
        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end

    it "shows each order's payment status on the list" do
      login_as cashier, scope: :user
      paid_delivery = Tenancy.with_business(business) do
        order = build(:order, :delivery, business: business, total: 100.0, subtotal: 95.0, payment_status: :paid)
        order.build_delivery_address(
          street: "Rua Augusta", number: "455", neighborhood: "Consolação",
          city: "São Paulo", state: "SP"
        )
        order.save!
        order
      end
      partial = Tenancy.with_business(business) do
        create(:order, :open, business: business, total: 50.0, subtotal: 50.0, payment_status: :partially_paid)
      end

      get orders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("orders.payment_statuses.paid"))
      expect(response.body).to include(I18n.t("orders.payment_statuses.partially_paid"))
      expect(response.body).to include("##{paid_delivery.id}")
      expect(response.body).to include("##{partial.id}")
    end

    it "loads the order list without querying per-order deliveries" do
      login_as cashier, scope: :user
      delivery_order(business)
      get orders_path
      small = select_count { get orders_path }

      delivery_order(business)
      delivery_order(business)
      big = select_count { get orders_path }

      expect(response).to have_http_status(:ok)
      expect(big - small).to be <= 1
    end

    it "shows an order with its items, payments and events" do
      login_as cashier, scope: :user
      order

      get "/orders/#{order.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Comanda")
    end

    it "hides orders from other businesses" do
      login_as cashier, scope: :user
      foreign_business = create(:business)
      foreign = Tenancy.with_business(foreign_business) { create(:order, business: foreign_business) }

      expect { get "/orders/#{foreign.id}" }.not_to raise_error
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "cancellation" do
    it "lets a cashier cancel an open order" do
      login_as cashier, scope: :user
      open_order = order(status: "open")

      post "/orders/#{open_order.id}/cancel"

      expect(response).to redirect_to("/orders")
      expect(Tenancy.with_business(business) { open_order.reload }).to be_cancelled
    end

    it "refuses a cashier to cancel an order already in the kitchen" do
      login_as cashier, scope: :user
      kitchen_order = paid_order(status: "in_kitchen", total: 10.0)

      post "/orders/#{kitchen_order.id}/cancel"

      expect(response).to have_http_status(:forbidden)
    end

    it "lets the owner force-cancel a paid order with a refund" do
      login_as owner, scope: :user
      paid_order = paid_order(status: "in_kitchen", total: 20.0)

      post "/orders/#{paid_order.id}/force_cancel"

      expect(response).to redirect_to("/orders")
      expect(Tenancy.with_business(business) { paid_order.reload }).to be_cancelled
      expect(Tenancy.with_business(business) { paid_order.payment_status }).to eq("refunded")
    end

    it "shows an error when cancelling an order that cannot be cancelled" do
      login_as owner, scope: :user
      paid_order = paid_order(status: "paid", total: 10.0)

      post "/orders/#{paid_order.id}/cancel"

      expect(response).to redirect_to(order_path(paid_order))
    end

    it "shows an error when force-cancelling an order that cannot be force-cancelled" do
      login_as owner, scope: :user
      open_order = order(status: "open")

      post "/orders/#{open_order.id}/force_cancel"

      expect(response).to redirect_to(order_path(open_order))
    end
  end

  describe "refunds" do
    it "refunds a paid order as owner" do
      login_as owner, scope: :user
      paid_order = paid_order(status: "paid", total: 10.0)

      post "/orders/#{paid_order.id}/refund"

      expect(response).to redirect_to(order_path(paid_order))
      expect(Tenancy.with_business(business) { paid_order.reload }).to be_refunded
    end

    it "shows an error when refunding an order that has not been paid" do
      login_as cashier, scope: :user
      open_order = order(status: "open")

      post "/orders/#{open_order.id}/refund"

      expect(response).to redirect_to(order_path(open_order))
    end
  end

  describe "delivery status" do
    it "marks a delivery out for delivery" do
      login_as cashier, scope: :user
      dlv = delivery_order(business)
      Tenancy.with_business(business) { dlv.create_delivery!(courier_name: "Carlos") }

      post "/orders/#{dlv.id}/out_for_delivery"

      expect(response).to redirect_to(order_path(dlv))
      expect(Tenancy.with_business(business) { dlv.delivery.reload.status }).to eq("out_for_delivery")
    end

    it "marks a delivery as delivered" do
      login_as cashier, scope: :user
      dlv = delivery_order(business)
      Tenancy.with_business(business) do
        dlv.create_delivery!(courier_name: "Carlos")
        dlv.delivery.update!(status: :out_for_delivery)
      end

      post "/orders/#{dlv.id}/delivered"

      expect(response).to redirect_to(order_path(dlv))
      expect(Tenancy.with_business(business) { dlv.delivery.reload.status }).to eq("delivered")
    end

    it "shows an alert when the order has no delivery record" do
      login_as cashier, scope: :user
      dlv = delivery_order(business)

      post "/orders/#{dlv.id}/out_for_delivery"

      expect(response).to redirect_to(order_path(dlv))
    end

    it "refuses kitchen staff" do
      login_as kitchen, scope: :user
      dlv = delivery_order(business)
      Tenancy.with_business(business) { dlv.create_delivery!(courier_name: "Carlos") }

      post "/orders/#{dlv.id}/out_for_delivery"

      expect(response).to have_http_status(:forbidden)
    end

    it "shows an alert when the delivery status cannot be updated" do
      login_as cashier, scope: :user
      dlv = delivery_order(business)
      Tenancy.with_business(business) { dlv.create_delivery!(courier_name: "Carlos") }
      allow_any_instance_of(Delivery).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(dlv.delivery))

      post "/orders/#{dlv.id}/out_for_delivery"

      expect(response).to redirect_to(order_path(dlv))
    end

    it "shows an alert when marking delivered fails" do
      login_as cashier, scope: :user
      dlv = delivery_order(business)
      Tenancy.with_business(business) do
        dlv.create_delivery!(courier_name: "Carlos")
        dlv.delivery.update!(status: :out_for_delivery)
      end
      allow_any_instance_of(Delivery).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(dlv.delivery))

      post "/orders/#{dlv.id}/delivered"

      expect(response).to redirect_to(order_path(dlv))
    end
  end
end
