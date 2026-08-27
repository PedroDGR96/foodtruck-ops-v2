require "rails_helper"

RSpec.describe "Compliance Dashboard", type: :request do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }

  describe "GET /compliance" do
    it "allows the owner to view the compliance dashboard" do
      login_as owner, scope: :user
      get "/compliance"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Conformidade LGPD")
    end

    it "forbids cashier from viewing the compliance dashboard" do
      login_as cashier, scope: :user
      get "/compliance"
      expect(response).to have_http_status(:forbidden)
    end

    it "displays consent stats" do
      Tenancy.with_business(business) do
        create(:consent_record, business: business)
        create(:consent_record, :withdrawn, business: business)
      end

      login_as owner, scope: :user
      get "/compliance"

      expect(response.body).to include("Consentimentos")
    end

    it "displays DSAR stats" do
      Tenancy.with_business(business) do
        create(:data_subject_request, business: business)
      end

      login_as owner, scope: :user
      get "/compliance"

      expect(response.body).to include("Solicitações")
    end

    it "displays incident stats" do
      Tenancy.with_business(business) do
        create(:privacy_incident, business: business)
      end

      login_as owner, scope: :user
      get "/compliance"

      expect(response.body).to include("Incidentes")
    end
  end
end
