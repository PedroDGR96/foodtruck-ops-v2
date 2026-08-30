require "rails_helper"

RSpec.describe "Data Subject Requests", type: :request do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }

  describe "GET /data_subject_requests" do
    it "allows the owner to list DSARs" do
      login_as owner, scope: :user
      get "/data_subject_requests"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Solicitações de Titular")
    end

    it "forbids cashier from listing DSARs" do
      login_as cashier, scope: :user
      get "/data_subject_requests"
      expect(response).to have_http_status(:forbidden)
    end

    it "only shows DSARs from the current business" do
      Tenancy.with_business(business) do
        create(:data_subject_request, business: business, data_subject_email: "owner@test.com")
      end
      other = create(:business)
      Tenancy.with_business(other) do
        create(:data_subject_request, business: other, data_subject_email: "other@test.com")
      end

      login_as owner, scope: :user
      get "/data_subject_requests"

      expect(response.body).to include("owner@test.com")
      expect(response.body).not_to include("other@test.com")
    end
  end

  describe "GET /data_subject_requests/new" do
    it "allows the owner to reach the new DSAR form" do
      login_as owner, scope: :user
      get "/data_subject_requests/new"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /data_subject_requests/:id" do
    it "allows the owner to view a DSAR" do
      dsar = Tenancy.with_business(business) do
        create(:data_subject_request, business: business)
      end

      login_as owner, scope: :user
      get "/data_subject_requests/#{dsar.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /data_subject_requests" do
    it "creates a new DSAR" do
      login_as owner, scope: :user

      post "/data_subject_requests", params: {
        data_subject_request: {
          data_subject_email: "titular@test.com",
          request_type: "access",
          description: "Solicito acesso aos meus dados."
        }
      }

      dsar = Tenancy.with_business(business) { DataSubjectRequest.last }
      expect(dsar.data_subject_email).to eq("titular@test.com")
      expect(dsar.request_type).to eq("access")
      expect(dsar.status).to eq("pending")
      expect(dsar.deadline_at).to be_present
    end

    it "sets IP and user agent" do
      login_as owner, scope: :user
      post "/data_subject_requests", params: {
        data_subject_request: {
          data_subject_email: "titular@test.com",
          request_type: "access"
        }
      }, headers: { "HTTP_USER_AGENT" => "TestAgent/1.0" }

      dsar = Tenancy.with_business(business) { DataSubjectRequest.last }
      expect(dsar.ip_address).to be_present
      expect(dsar.user_agent).to be_present
    end

    it "re-renders form with invalid params" do
      login_as owner, scope: :user
      post "/data_subject_requests", params: {
        data_subject_request: {
          data_subject_email: "invalid",
          request_type: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /data_subject_requests/:id" do
    it "updates the DSAR status" do
      dsar = Tenancy.with_business(business) do
        create(:data_subject_request, business: business)
      end

      login_as owner, scope: :user
      patch "/data_subject_requests/#{dsar.id}", params: {
        data_subject_request: { status: "in_progress" }
      }

      expect(Tenancy.with_business(business) { dsar.reload.status }).to eq("in_progress")
    end

    it "completes the DSAR" do
      dsar = Tenancy.with_business(business) do
        create(:data_subject_request, business: business)
      end

      login_as owner, scope: :user
      patch "/data_subject_requests/#{dsar.id}", params: {
        data_subject_request: { status: "completed" }
      }

      reloaded = Tenancy.with_business(business) { dsar.reload }
      expect(reloaded.status).to eq("completed")
      expect(reloaded.completed_at).to be_present
    end
  end
end
