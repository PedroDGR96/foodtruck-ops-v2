require "rails_helper"

RSpec.describe "Cash Registers", type: :request do
  let(:business) { create(:business) }
  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  describe "GET /cash_registers" do
    it "allows all staff roles" do
      [ owner, cashier, kitchen ].each do |user|
        login_as user, scope: :user
        get cash_registers_path
        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end

    it "loads the shift history without querying per-register users" do
      login_as owner, scope: :user
      Tenancy.with_business(business) { create(:cash_register, :closed, business: business) }
      get cash_registers_path
      small = select_count { get cash_registers_path }

      Tenancy.with_business(business) { create_list(:cash_register, 2, :closed, business: business) }
      big = select_count { get cash_registers_path }

      expect(response).to have_http_status(:ok)
      expect(big - small).to be <= 1
    end
  end

  describe "GET /cash_registers/:id" do
    it "allows owner and cashier to view a shift" do
      register = Tenancy.with_business(business) { create(:cash_register, :open, business: business) }

      [ owner, cashier ].each do |user|
        login_as user, scope: :user
        get cash_register_path(register)
        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end
  end

  describe "GET /cash_registers/new" do
    it "allows owner and cashier to open the new form" do
      [ owner, cashier ].each do |user|
        login_as user, scope: :user
        get new_cash_register_path
        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end
  end

  describe "POST /cash_registers" do
    before { login_as cashier, scope: :user }

    it "opens a new shift" do
      post cash_registers_path, params: { cash_register: { opening_amount: 200.0 } }

      expect(response).to redirect_to(cash_register_path(Tenancy.with_business(business) { CashRegister.last }))
      register = Tenancy.with_business(business) { CashRegister.last }
      expect(register).to be_open
      expect(register.opening_amount).to eq(200.0)
    end

    it "rejects invalid opening amount" do
      post cash_registers_path, params: { cash_register: { opening_amount: -10 } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects opening when another shift is already open" do
      Tenancy.with_business(business) { create(:cash_register, :open, business: business, user: cashier) }

      post cash_registers_path, params: { cash_register: { opening_amount: 50.0 } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /cash_registers/:id/close" do
    let(:register) do
      Tenancy.with_business(business) { create(:cash_register, :open, business: business, user: cashier) }
    end

    before { login_as cashier, scope: :user }

    it "closes the shift" do
      post close_cash_register_path(register), params: { cash_register: { actual_closing_amount: 100.0 } }

      expect(response).to redirect_to(cash_register_path(register))
      expect(Tenancy.with_business(business) { register.reload }).to be_closed
    end

    it "handles already closed shift error" do
      Tenancy.with_business(business) { register.close!(actual_closing_amount: 100.0, actor: cashier) }
      login_as owner, scope: :user

      post close_cash_register_path(register), params: { cash_register: { actual_closing_amount: 100.0 } }

      expect(response).to redirect_to(cash_register_path(register))
      expect(flash[:alert]).to be_present
    end

    it "renders show on validation error during close" do
      login_as owner, scope: :user

      post close_cash_register_path(register), params: { cash_register: { actual_closing_amount: "-5" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a blank closing amount instead of closing at zero" do
      post close_cash_register_path(register), params: { cash_register: { actual_closing_amount: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Tenancy.with_business(business) { register.reload }).to be_open
    end
  end

  describe "POST /cash_registers/:id/cash_movements" do
    before { login_as cashier, scope: :user }

    it "records a cash movement" do
      register = Tenancy.with_business(business) { create(:cash_register, :open, business: business, user: cashier) }

      post cash_register_cash_movements_path(register), params: {
        cash_movement: { movement_type: "income", category: "cash_drop", amount: 25.0, reason: "Cash in" }
      }

      expect(response).to redirect_to(cash_register_path(register))
      expect(Tenancy.with_business(business) { register.cash_movements.count }).to eq(1)
    end

    it "handles invalid movement data" do
      register = Tenancy.with_business(business) { create(:cash_register, :open, business: business, user: cashier) }

      post cash_register_cash_movements_path(register), params: {
        cash_movement: { movement_type: "income", category: "cash_drop", amount: 0, reason: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
