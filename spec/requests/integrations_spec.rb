require "rails_helper"

RSpec.describe "Integrations", type: :request do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }

  describe "GET /integrations/edit" do
    it "renders the integrations page for owner" do
      login_as owner, scope: :user
      get "/integrations/edit"
      expect(response).to have_http_status(:ok)
    end

    it "forbids cashier" do
      login_as cashier, scope: :user
      get "/integrations/edit"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /integrations" do
    before { login_as owner, scope: :user }

    it "updates integration settings" do
      patch "/integrations", params: {
        integrations: {
          "payment_gateway" => {
            "enabled" => "1",
            "credentials" => { "public_key" => "APP_USR-test" }
          }
        }
      }

      expect(response).to redirect_to("/integrations/edit")
      setting = Tenancy.with_business(business) { business.integration_settings.find_by(provider_key: "payment_gateway") }
      expect(setting).to be_present
      expect(setting.enabled).to be true
      expect(setting.credentials["public_key"]).to eq("APP_USR-test")
    end

    it "disables a provider" do
      Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "messaging", enabled: true, credentials: {})
      end

      patch "/integrations", params: {
        integrations: {
          "messaging" => { "enabled" => "0", "credentials" => {} }
        }
      }

      expect(response).to redirect_to("/integrations/edit")
      setting = Tenancy.with_business(business) { business.integration_settings.find_by(provider_key: "messaging") }
      expect(setting.enabled).to be false
    end

    it "handles nil credentials gracefully" do
      patch "/integrations", params: {
        integrations: {
          "maps" => { "enabled" => "1" }
        }
      }

      expect(response).to redirect_to("/integrations/edit")
    end
  end

  describe "POST /integrations/test/:provider" do
    before { login_as owner, scope: :user }

    it "tests payment gateway connection without credentials" do
      post "/integrations/test/payment_gateway", params: { provider: "payment_gateway" }, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(false)
    end

    it "tests payment gateway connection with credentials" do
      Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "payment_gateway",
               credentials: { "public_key" => "APP_USR-1234" }, enabled: true)
      end
      post "/integrations/test/payment_gateway", params: { provider: "payment_gateway" }, as: :json
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(true)
    end

    it "tests messaging connection without credentials" do
      post "/integrations/test/messaging", params: { provider: "messaging" }, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(false)
    end

    it "tests messaging connection with credentials" do
      Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "messaging",
               credentials: { "twilio_account_sid" => "AC123456", "twilio_auth_token" => "tok123" }, enabled: true)
      end
      post "/integrations/test/messaging", params: { provider: "messaging" }, as: :json
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(true)
    end

    it "tests fiscal connection in homologacao" do
      post "/integrations/test/fiscal", params: { provider: "fiscal" }, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(true)
    end

    it "tests fiscal connection in production with cnpj" do
      Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "fiscal",
               credentials: { "environment" => "producao", "cnpj" => "12345678000190" }, enabled: true)
      end
      post "/integrations/test/fiscal", params: { provider: "fiscal" }, as: :json
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(true)
    end

    it "tests fiscal connection in production without cnpj" do
      Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "fiscal",
               credentials: { "environment" => "producao" }, enabled: true)
      end
      post "/integrations/test/fiscal", params: { provider: "fiscal" }, as: :json
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(false)
    end

    it "tests marketplace connection without credentials" do
      post "/integrations/test/marketplace", params: { provider: "marketplace" }, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(false)
    end

    it "tests marketplace connection with credentials" do
      Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "marketplace",
               credentials: { "merchant_id" => "42", "platform" => "99food" }, enabled: true)
      end
      post "/integrations/test/marketplace", params: { provider: "marketplace" }, as: :json
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(true)
    end

    it "tests maps connection with api key" do
      Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "maps",
               credentials: { "api_key" => "AIzaSy123" }, enabled: true)
      end
      post "/integrations/test/maps", params: { provider: "maps" }, as: :json
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(true)
    end

    it "returns unsupported for unknown provider" do
      post "/integrations/test/bogus", params: { provider: "bogus" }, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to eq(false)
    end

    it "handles maps connection errors gracefully" do
      allow(OsmMapsProvider).to receive(:geocode).and_raise(RuntimeError, "boom")
      post "/integrations/test/maps", params: { provider: "maps" }, as: :json
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["message"]).to include("boom")
    end
  end

  describe "PATCH /integrations error handling" do
    before { login_as owner, scope: :user }

    it "renders edit on ActiveRecord::RecordInvalid" do
      setting = nil
      Tenancy.with_business(business) do
        setting = create(:integration_setting, business: business, provider_key: "payment_gateway",
                         credentials: { "public_key" => "old" }, enabled: true)
      end
      allow_any_instance_of(IntegrationSetting).to receive(:update!).and_raise(
        ActiveRecord::RecordInvalid.new(setting)
      )

      patch "/integrations", params: {
        integrations: {
          "payment_gateway" => {
            "enabled" => "1",
            "credentials" => { "public_key" => "new" }
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
