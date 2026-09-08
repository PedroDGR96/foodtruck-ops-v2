require "rails_helper"

RSpec.describe "Integration adapter mode toggle", type: :request do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  let(:owner) { staff(:owner) }

  describe "GET /integrations/edit" do
    before { login_as owner, scope: :user }

    it "renders the adapter mode section for the owner" do
      get "/integrations/edit"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Modo de execução")
      expect(response.body).to include("Demo (mock)")
      expect(response.body).to include("Ao vivo")
    end

    it "does not render the adapter mode section for a guest" do
      logout(:user)
      get "/integrations/edit"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "badges a fallback provider when live" do
      business.update!(integration_adapter_mode: "live")
      get "/integrations/edit"
      expect(response.body).to include("cai para mock")
      expect(response.body).to include("mock como fallback")
    end
  end

  describe "PATCH /integrations (toggle)" do
    before { login_as owner, scope: :user }

    it "sets the business to live mode" do
      patch "/integrations", params: {
        business: { integration_adapter_mode: "live" }
      }
      expect(response).to redirect_to("/integrations/edit")
      expect(Tenancy.with_business(business) { business.reload.live? }).to be(true)
    end

    it "sets the business back to mock mode" do
      business.update!(integration_adapter_mode: "live")
      patch "/integrations", params: {
        business: { integration_adapter_mode: "mock" }
      }
      expect(Tenancy.with_business(business) { business.reload.mock? }).to be(true)
    end

    it "still saves integration settings when toggling without providers" do
      patch "/integrations", params: {
        business: { integration_adapter_mode: "live" },
        integrations: {
          "payment_gateway" => {
            "enabled" => "1",
            "credentials" => { "public_key" => "APP_USR-test" }
          }
        }
      }
      expect(response).to redirect_to("/integrations/edit")
      expect(Tenancy.with_business(business) { business.reload.live? }).to be(true)
    end
  end
end
