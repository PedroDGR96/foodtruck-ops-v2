require "rails_helper"

RSpec.describe "Kitchen display", type: :request do
  let(:business) { create(:business) }
  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  def paid_order(status: "paid", kitchen_status: "pending", **attrs)
    Tenancy.with_business(business) do
      o = create(:order, :open, business: business, total: 10.0, subtotal: 10.0)
      create(:payment, order: o, amount: 10.0)
      o.update!(status: status, payment_status: :paid, kitchen_status: kitchen_status, **attrs)
      o
    end
  end

  describe "access" do
    it "lets every staff role open the kitchen display" do
      [ owner, cashier, kitchen ].each do |user|
        login_as user, scope: :user
        get "/kitchen"
        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end
  end

  describe "queue" do
    before { login_as kitchen, scope: :user }

    it "lists only paid orders waiting or in progress" do
      waiting = paid_order(status: "paid", kitchen_status: "pending")
      cooking = paid_order(status: "in_kitchen", kitchen_status: "in_progress")
      done = paid_order(status: "ready", kitchen_status: "done")
      draft = Tenancy.with_business(business) { create(:order, business: business) }

      get "/kitchen"

      expect(response.body).to include(%(id="order_#{waiting.id}"))
      expect(response.body).to include(%(id="order_#{cooking.id}"))
      expect(response.body).not_to include(%(id="order_#{done.id}"))
      expect(response.body).not_to include(%(id="order_#{draft.id}"))
    end
  end

  describe "cooking" do
    before { login_as kitchen, scope: :user }

    it "starts cooking a paid order" do
      order = paid_order(status: "paid", kitchen_status: "pending")

      post "/kitchen/orders/#{order.id}/start"

      expect(response).to redirect_to("/kitchen")
      expect(Tenancy.with_business(business) { order.reload }).to be_in_kitchen
      expect(Tenancy.with_business(business) { order.kitchen_status }).to eq("in_progress")
    end

    it "marks an in-progress order ready" do
      order = paid_order(status: "in_kitchen", kitchen_status: "in_progress")

      post "/kitchen/orders/#{order.id}/done"

      expect(response).to redirect_to("/kitchen")
      expect(Tenancy.with_business(business) { order.reload }).to be_ready
      expect(Tenancy.with_business(business) { order.kitchen_status }).to eq("done")
    end

    it "refuses to start an unpaid order without a 500" do
      open = Tenancy.with_business(business) { create(:order, :open, business: business) }

      post "/kitchen/orders/#{open.id}/start"

      expect(response).to redirect_to("/kitchen")
      expect(flash[:alert]).to be_present
      expect(Tenancy.with_business(business) { open.reload }).to be_open
    end

    it "refuses to mark a not-started order done" do
      order = paid_order(status: "paid", kitchen_status: "pending")

      post "/kitchen/orders/#{order.id}/done"

      expect(response).to redirect_to("/kitchen")
      expect(flash[:alert]).to be_present
      expect(Tenancy.with_business(business) { order.reload }).not_to be_ready
    end
  end

  describe "completed panel" do
    before { login_as kitchen, scope: :user }

    it "lists recently finished orders with the prep timer markup" do
      done = paid_order(status: "ready", kitchen_status: "done")
      Tenancy.with_business(business) { done.update!(finished_at: Time.current) }

      get "/kitchen"

      expect(response.body).to include("completed_order_#{done.id}")
      expect(response.body).to include(I18n.t("kitchen.completed"))
      expect(response.body).to include("Pronto às")
    end

    it "flags overdue tickets" do
      paid_order(status: "in_kitchen", kitchen_status: "in_progress", started_at: 20.minutes.ago)

      get "/kitchen"

      expect(response.body).to include("is-overdue")
      expect(response.body).to include(I18n.t("kitchen.overdue"))
    end
  end

  describe "permissions" do
    it "lets the owner start and finish orders" do
      login_as owner, scope: :user
      order = paid_order(status: "paid", kitchen_status: "pending")

      post "/kitchen/orders/#{order.id}/start"
      expect(response).to redirect_to("/kitchen")

      post "/kitchen/orders/#{order.id}/done"
      expect(response).to redirect_to("/kitchen")
      expect(Tenancy.with_business(business) { order.reload }).to be_ready
    end

    it "forbids a cashier from starting orders" do
      login_as cashier, scope: :user
      order = paid_order(status: "paid", kitchen_status: "pending")

      post "/kitchen/orders/#{order.id}/start"

      expect(response).to have_http_status(:forbidden)
      expect(Tenancy.with_business(business) { order.reload }).not_to be_in_kitchen
    end
  end
end
