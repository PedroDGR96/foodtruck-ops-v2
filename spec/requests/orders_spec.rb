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
end
