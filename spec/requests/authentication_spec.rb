require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }

  def reload_user(user)
    Tenancy.with_business(business) { user.reload }
  end

  def audit_count(action)
    Tenancy.with_business(business) { AuditLog.unscoped.where(action: action).count }
  end

  describe "guest access" do
    it "redirects unauthenticated users to sign in" do
      get "/"

      expect(response).to redirect_to(new_user_session_path)
    end

    it "serves the sign in page" do
      get new_user_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Acessar sua empresa")
    end
  end

  describe "signing in" do
    it "redirects to the root path and records an audit row" do
      post "/users/sign_in", params: { user: { email: owner.email, password: "password123" } }

      expect(response).to redirect_to(root_path)
      expect(audit_count("sign_in")).to eq(1)
    end

    it "rejects a wrong password and records a failed attempt" do
      post "/users/sign_in", params: { user: { email: owner.email, password: "wrong-password" } }

      expect(response.status).to be_in([ 200, 422 ])
      expect(reload_user(owner).failed_attempts).to eq(1)
      expect(audit_count("failed_sign_in")).to eq(1)
    end

    it "rejects an unknown email without leaking account existence" do
      post "/users/sign_in", params: { user: { email: "nobody@example.test", password: "password123" } }

      expect(response.status).to be_in([ 200, 422 ])
    end

    it "rejects an inactive account" do
      inactive = Tenancy.with_business(business) { create(:user, business: business, active: false) }

      post "/users/sign_in", params: { user: { email: inactive.email, password: "password123" } }

      expect(response).to redirect_to(new_user_session_path)
      expect(audit_count("failed_sign_in")).to eq(1)
    end
  end

  describe "locking" do
    it "locks the account after the maximum number of failed attempts" do
      5.times do
        post "/users/sign_in", params: { user: { email: owner.email, password: "wrong-password" } }
      end

      expect(reload_user(owner).locked_at).not_to be_nil
      expect(audit_count("user_locked")).to eq(1)
      expect(audit_count("failed_sign_in")).to eq(5)

      post "/users/sign_in", params: { user: { email: owner.email, password: "password123" } }

      expect(response).not_to redirect_to(root_path)
    end

    it "unlocks the account after the configured time" do
      5.times do
        post "/users/sign_in", params: { user: { email: owner.email, password: "wrong-password" } }
      end
      expect(reload_user(owner).locked_at).not_to be_nil

      travel(31.minutes) do
        post "/users/sign_in", params: { user: { email: owner.email, password: "password123" } }
      end

      expect(response).to redirect_to(root_path)
      expect(audit_count("user_unlocked")).to eq(1)
    end
  end

  describe "signing out" do
    it "signs out and records an audit row" do
      login_as owner, scope: :user

      delete "/users/sign_out"

      expect(response).to redirect_to(new_user_session_path)
      expect(audit_count("sign_out")).to eq(1)
    end
  end

  describe "session timeout" do
    it "expires an idle session after the configured timeout" do
      post "/users/sign_in", params: { user: { email: owner.email, password: "password123" } }
      expect(response).to redirect_to(root_path)

      travel(3.hours) { get "/" }

      expect(response).to redirect_to(root_path)

      get "/"

      expect(response).to redirect_to(new_user_session_path)
    end

    it "keeps an active session alive" do
      post "/users/sign_in", params: { user: { email: owner.email, password: "password123" } }
      expect(response).to redirect_to(root_path)

      travel(1.hour) { get "/" }

      expect(response).to have_http_status(:ok)
    end
  end
end
