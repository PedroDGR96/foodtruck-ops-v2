require "rails_helper"

RSpec.describe OrderPaymentController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:business) { create(:business) }
  let!(:owner_user) { Tenancy.with_business(business) { create(:user, role: :owner, business: business) } }
  let!(:cashier_user) { Tenancy.with_business(business) { create(:user, role: :cashier, business: business) } }

  before do
    Current.business = business
  end

  def set_tenant_context!
    Current.business = business
    @owner_user ||= owner_user
    @business ||= business
  end

  describe "#show" do
    context "for an open order" do
      let!(:open_order) do
        Tenancy.with_business(business) { create(:order, status: :open, total: 100.0) }
      end

      it "redirects to new_order_payment_path when no step is provided" do
        sign_in(owner_user)
        get :show, params: { order_id: open_order.id }
        expect(response).to redirect_to(new_order_payment_path(open_order))
      end

      it "renders the show template with step = 1 when step covers status" do
        sign_in(owner_user)
        get :show, params: { order_id: open_order.id, step: 1 }
        expect(response).to render_template("order_payment/show")
        expect(assigns(:step)).to eq(1)
      end

      it "renders the show template with step = 2 when step covers status + 1" do
        sign_in(owner_user)
        get :show, params: { order_id: open_order.id, step: 2 }
        expect(response).to render_template("order_payment/show")
        expect(assigns(:step)).to eq(2)
      end

      it "redirects with flash alert for invalid step number" do
        sign_in(owner_user)
        get :show, params: { order_id: open_order.id, step: 99 }
        expect(response).to redirect_to(new_order_payment_path(order: open_order))
        expect(flash[:alert]).to include("Invalid payment step")
      end

      it "redirects with alert for already paid orders" do
        sign_in(owner_user)
        paid_order = Tenancy.with_business(business) { create(:order, status: :paid, total: 100.0) }
        get :show, params: { order_id: paid_order.id, step: 1 }
        expect(response).to redirect_to(new_order_payment_path(paid_order))
      end

      context "renders show with correct amount for step 1" do
        before do
          payment = open_order.payments.build(method: "card", amount: 0.0, gateway_reference: "step_1")
          payment.save!
        end

        it "returns the built payment object" do
          sign_in(owner_user)
          get :show, params: { order_id: open_order.id, step: 1 }
          expect(assigns(:payment)).to eq(open_order.payments.first)
        end
      end

      context "renders show with correct amount for later steps" do
        before do
          partial = create(:order, status: :partially_paid, total: 100.0)
          payment = partial.payments.build(method: "card", amount: 50.0, gateway_reference: "step_1")
          payment.save!
        end

        it "returns the built payment object" do
          sign_in(owner_user)
          get :show, params: { order_id: open_order.id, step: 2 }
          expected_payment = partial.payments.build(method: "card", amount: 50.0, gateway_reference: "step_2")
          expect(assigns(:payment)).to eq(expected_payment)
        end
      end
    end

    context "for a paid/closed order" do
      let!(:paid_order) { Tenancy.with_business(business) { create(:order, status: :paid, total: 100.0) } }

      it "redirects with alert for any step number" do
        sign_in(owner_user)
        get :show, params: { order_id: paid_order.id, step: 5 }
        expect(response).to redirect_to(new_order_payment_path(paid_order))
        expect(flash[:alert]).to include("Invalid payment step")
      end
    end

    context "for an invalid order" do
      it "raises ActiveRecord::RecordNotFound" do
        sign_in(owner_user)
        expect { get :show, params: { order_id: "999" } }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "requires pay? authorization via policy" do
        sign_in(cashier_user)
        open_order.reload
        expect { get :show, params: { order_id: open_order.id } }.to raise_error(ActionController::AuthorizationError)
      end
    end
  end

  describe "#create" do
    it "redirects to next step after successful partial payment" do
      sign_in(owner_user)
      Tenancy.with_business(business) do
        open_order = create(:order, status: :open, total: 100.0)
        post :create, params: { order_id: open_order.id, amount: 50.0 }
        expect(response).to redirect_to(new_order_payment_path(order: open_order))

        open_order.reload
        expect(open_order.payment_status).to eq("partially_paid")
      end
    end

    it "redirects to same step when amount is zero" do
      sign_in(owner_user)
      Tenancy.with_business(business) do
        open_order = create(:order, status: :open, total: 100.0)
        post :create, params: { order_id: open_order.id, amount: 0.0 }
        expect(response).to redirect_to(new_order_payment_path(order: open_order))
      end
    end

    it "redirects to current step when zero amount is entered later" do
      sign_in(owner_user)
      Tenancy.with_business(business) do
        open_order = create(:order, status: :open, total: 100.0)
        post :create, params: { order_id: open_order.id, step: 2, amount: 0.0 }
        expect(response).to redirect_to(new_order_payment_path(order: open_order))
      end
    end

    it "redirects with flash alert for negative amounts" do
      sign_in(owner_user)
      Tenancy.with_business(business) do
        open_order = create(:order, status: :open, total: 100.0)
        post :create, params: { order_id: open_order.id, step: 1, amount: -50.0 }
        expect(response).to redirect_to(new_order_payment_path(order: open_order))
      end
    end

    it "renders the new payment form when validation fails" do
      sign_in(owner_user)
      Tenancy.with_business(business) do
        open_order = create(:order, status: :open, total: 100.0)
        post :create, params: { order_id: open_order.id, step: 2, amount: -50.0 }
        expect(response).to render_template("order_payment/new")
      end
    end

    it "records payment and advances to paid when fully paying" do
      sign_in(owner_user)
      Tenancy.with_business(business) do
        open_order = create(:order, status: :open, total: 100.0)
        post :create, params: { order_id: open_order.id, step: 1, amount: 100.0 }

        open_order.reload
        expect(open_order.payment_status).to eq("paid")
      end
    end

    it "does not change status if payment exceeds order total" do
      sign_in(owner_user)
      Tenancy.with_business(business) do
        open_order = create(:order, status: :open, total: 100.0)
        post :create, params: { order_id: open_order.id, step: 1, amount: 500.0 }

        open_order.reload
        expect(open_order.payment_status).to eq("pending")
      end
    end

    context "for a closed/paid order" do
      let!(:paid_order) { Tenancy.with_business(business) { create(:order, status: :paid, total: 100.0) } }

      it "redirects with alert when attempting new payment" do
        sign_in(owner_user)
        post :create, params: { order_id: paid_order.id, amount: 50.0 }
        expect(response).to redirect_to(new_order_payment_path(paid_order))
      end
    end
  end

  describe "#record_payment!" do
    it "advances status from open to partially_paid" do
      sign_in(owner_user)
      lifecycle = OrderLifecycle.new(open_order, owner_user) rescue nil

      expect { lifecycle&.record_payment! }.not_to raise_error

      open_order.reload
      expect(open_order.payment_status).to eq("partially_paid")
    end

    it "advances status from partially_paid to paid when fully covered" do
      sign_in(owner_user)
      Tenancy.with_business(business) do
        partial_order = create(:order, status: :partially_paid, total: 100.0)
        payment = partial_order.payments.build(method: "card", amount: 50.0, gateway_reference: "step_1")
        payment.save!
      end

      lifecycle = OrderLifecycle.new(partial_order, owner_user)
      payment = partial_order.payments.build(method: "card", amount: 50.0, gateway_reference: "step_2")

      expect { lifecycle.record_payment!(payment) }.not_to raise_error

      partial_order.reload
      expect(partial_order.payment_status).to eq("paid")
    end

    it "does not change status for overpayment" do
      sign_in(owner_user)
      lifecycle = OrderLifecycle.new(open_order, owner_user) rescue nil

      expect { lifecycle&.record_payment! }.not_to raise_error

      open_order.reload
      expect(open_order.payment_status).to eq("pending")
    end

    context "for a closed order" do
      let!(:paid_order) { Tenancy.with_business(business) { create(:order, status: :paid, total: 100.0) } }

      it "raises IllegalTransition for payment on paid order" do
        sign_in(owner_user)
        lifecycle = OrderLifecycle.new(paid_order, owner_user)
        payment = paid_order.payments.build(method: "card", amount: 50.0, gateway_reference: "step_1")

        expect { lifecycle.record_payment!(payment) }.to raise_error(OrderLifecycle::IllegalTransition)
      end
    end
  end

  describe "#update_order_status_after_payment" do
    it "updates status to paid when payment covers full balance" do
      sign_in(owner_user)
      Tenancy.with_business(business) { create(:order, status: :open, total: 100.0) }

      expect { described_class.instance_method(:update_order_status_after_payment).call }.not_to raise_error

      open_order.reload
      expect(open_order.payment_status).to eq("paid")
    end

    it "updates status to partially_paid when payment does not cover full balance" do
      sign_in(owner_user)
      Tenancy.with_business(business) { create(:order, status: :open, total: 100.0) }

      expect { described_class.instance_method(:update_order_status_after_payment).call }.not_to raise_error

      open_order.reload
      expect(open_order.payment_status).to eq("partially_paid")
    end
  end

  describe "#calculate_amount_for_step" do
    it "returns full balance for step 1" do
      sign_in(owner_user)
      payment = open_order.payments.build(method: "card", amount: 0.0, gateway_reference: "step_1")
      payment.save!

      expected_amount = open_order.total - payment.amount
      expect(described_class.send(:calculate_amount_for_step, open_order, 1)).to eq(expected_amount)
    end

    it "returns full balance for step 2" do
      sign_in(owner_user)
      partial_order = create(:order, status: :partially_paid, total: 100.0)

      expect(described_class.send(:calculate_amount_for_step, partial_order, 2)).to eq(50.0) # half of 100
    end

    it "returns full balance for step N when overpayment is expected" do
      sign_in(owner_user)

      expect(described_class.send(:calculate_amount_for_step, open_order, 3)).to be > 50
    end

    context "when order is fully paid" do
      let!(:paid_order) { Tenancy.with_business(business) { create(:order, status: :paid, total: 100.0) } }

      it "returns a minimal positive amount for validation" do
        sign_in(owner_user)
        expect(described_class.send(:calculate_amount_for_step, paid_order, 3)).to be > 0
      end
    end
  end
end
