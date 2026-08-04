require "rails_helper"

RSpec.describe "Payments", type: :request do
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

  describe "new payment form" do
    it "lets an owner or cashier open the form" do
      [ owner, cashier ].each do |user|
        login_as user, scope: :user
        get "/orders/#{open_order.id}/payments/new"
        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end

    it "forbids kitchen staff from the payment form" do
      login_as kitchen, scope: :user
      get "/orders/#{open_order.id}/payments/new"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "recording a payment" do
    before { login_as cashier, scope: :user }

    it "marks the order paid when the payment covers the total" do
      order = open_order

      post "/orders/#{order.id}/payments", params: { payment: { method: "pix", amount: 40.0 } }

      expect(response).to redirect_to(order_path(order))
      expect(Tenancy.with_business(business) { order.reload }).to be_paid
      expect(Tenancy.with_business(business) { order.payments.size }).to eq(1)
    end

    it "stays partial and offers another payment for a split payment" do
      order = open_order

      post "/orders/#{order.id}/payments", params: { payment: { method: "cash", amount: 15.0 } }

      expect(response).to redirect_to(new_order_payment_path(order))
      expect(Tenancy.with_business(business) { order.reload }).to be_partially_paid

      post "/orders/#{order.id}/payments", params: { payment: { method: "card", amount: 25.0 } }

      expect(Tenancy.with_business(business) { order.reload }).to be_paid
    end

    it "rejects a payment above the remaining balance" do
      order = open_order

      post "/orders/#{order.id}/payments", params: { payment: { method: "card", amount: 999.0 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Tenancy.with_business(business) { order.reload }).to be_open
    end

    it "rejects a payment with no amount" do
      order = open_order

      post "/orders/#{order.id}/payments", params: { payment: { method: "card", amount: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Tenancy.with_business(business) { order.payments.empty? }).to be(true)
    end
  end
end
