require "rails_helper"

RSpec.describe "Order payment flow (checkout)", type: :request do
  let(:business) { create(:business) }
  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  def open_order(total: 40.0)
    Tenancy.with_business(business) do
      create(:order, :open, business: business, total: total, subtotal: total)
    end
  end

  def order_state(order)
    Tenancy.with_business(business) { order.reload }
  end

  def payment_count(order)
    Tenancy.with_business(business) { order.reload.payments.size }
  end

  describe "GET /checkout/:order_id" do
    it "lets an owner or cashier open the checkout form" do
      order = open_order

      [ owner, cashier ].each do |user|
        login_as user, scope: :user
        get checkout_path(order)
        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end

    it "forbids kitchen staff from the checkout form" do
      login_as kitchen, scope: :user
      get checkout_path(open_order)
      expect(response).to have_http_status(:forbidden)
    end

    it "suggests the amount to pay at the current step" do
      order = open_order(total: 40.0)
      login_as cashier, scope: :user
      get checkout_path(order)
      expect(response.body).to include("R$ 20,00")
    end

    it "redirects with an alert for an invalid step" do
      order = open_order
      login_as cashier, scope: :user
      get checkout_step_path(order, 9)
      expect(response).to redirect_to(checkout_path(order))
      expect(flash[:alert]).to be_present
    end

    it "shows the remaining balance for a partially paid order" do
      order = open_order(total: 40.0)
      login_as cashier, scope: :user
      post checkout_path(order), params: { payment: { amount: 15.0 } }
      expect(order_state(order)).to be_partially_paid

      get checkout_path(order)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("R$ 25,00")
    end

    it "shows the payment history for a paid order" do
      order = open_order(total: 40.0)
      login_as cashier, scope: :user
      post checkout_path(order), params: { payment: { amount: 40.0 } }
      expect(order_state(order)).to be_paid

      get checkout_path(order)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Este pedido já foi pago")
    end
  end

  describe "POST /checkout/:order_id" do
    before { login_as cashier, scope: :user }

    it "marks the order paid when the payment covers the total" do
      order = open_order

      post checkout_path(order), params: { payment: { amount: 40.0 } }

      expect(response).to redirect_to(order_path(order))
      expect(order_state(order)).to be_paid
      expect(payment_count(order)).to eq(1)
    end

    it "stays partial and offers another payment for a split payment" do
      order = open_order

      post checkout_path(order), params: { payment: { amount: 15.0 } }

      expect(response).to redirect_to(checkout_path(order))
      expect(order_state(order)).to be_partially_paid

      post checkout_path(order), params: { payment: { amount: 25.0 } }

      expect(response).to redirect_to(order_path(order))
      expect(order_state(order)).to be_paid
    end

    it "rejects a payment above the remaining balance" do
      order = open_order

      post checkout_path(order), params: { payment: { amount: 999.0 } }

      expect(response).to redirect_to(checkout_path(order))
      expect(order_state(order)).to be_open
    end

    it "records the payment with the selected method" do
      order = open_order

      post checkout_path(order), params: { payment: { method: "pix", amount: 40.0 } }

      expect(response).to redirect_to(order_path(order))
      expect(order_state(order)).to be_paid
      payment = Tenancy.with_business(business) { order.payments.last }
      expect(payment.method).to eq("pix")
      expect(payment.amount).to eq(40.0)
    end

    it "redirects with an alert when the amount is zero" do
      order = open_order

      post checkout_path(order), params: { payment: { amount: 0 } }

      expect(response).to redirect_to(checkout_path(order))
      expect(flash[:alert]).to be_present
      expect(payment_count(order)).to eq(0)
    end

    it "redirects with an alert when the amount is negative" do
      order = open_order

      post checkout_path(order), params: { payment: { amount: -10 } }

      expect(response).to redirect_to(checkout_path(order))
      expect(flash[:alert]).to be_present
      expect(payment_count(order)).to eq(0)
    end

    it "redirects with an alert when the order no longer accepts payment" do
      order = open_order
      post checkout_path(order), params: { payment: { amount: 15.0 } }
      expect(order_state(order)).to be_partially_paid

      Tenancy.with_business(business) do
        OrderLifecycle.new(order, cashier).start_cooking!
      end
      expect(order_state(order)).to be_in_kitchen

      post checkout_path(order), params: { payment: { amount: 25.0 } }

      expect(response).to redirect_to(checkout_path(order))
      expect(flash[:alert]).to eq(I18n.t("orders.cannot_pay"))
      expect(payment_count(order)).to eq(1)
    end

    it "redirects with an alert for an already paid order" do
      order = open_order
      post checkout_path(order), params: { payment: { amount: 40.0 } }
      expect(order_state(order)).to be_paid

      post checkout_path(order), params: { payment: { amount: 5.0 } }

      expect(response).to redirect_to(checkout_path(order))
      expect(flash[:alert]).to be_present
      expect(payment_count(order)).to eq(1)
    end
  end
end
