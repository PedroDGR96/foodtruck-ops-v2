require "rails_helper"

RSpec.describe "Authorization", type: :request do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }
  let(:kitchen) { staff(:kitchen) }

  def reload_user(user)
    Tenancy.with_business(business) { user.reload }
  end

  describe "role access matrix" do
    it "lets every role reach the home page" do
      [ owner, cashier, kitchen ].each do |user|
        login_as user, scope: :user
        get "/"

        expect(response).to have_http_status(:ok)
        logout(:user)
      end
    end

    it "lets the owner manage users" do
      login_as owner, scope: :user
      target = Tenancy.with_business(business) { create(:user, :cashier, business: business) }

      get "/users"
      expect(response).to have_http_status(:ok)

      get "/users/new"
      expect(response).to have_http_status(:ok)

      get "/users/#{target.id}/edit"
      expect(response).to have_http_status(:ok)

      post "/users", params: { user: { name: "New Staff", email: "new@example.test", role: "cashier", password: "password123" } }
      expect(response).to redirect_to("/users")

      patch "/users/#{target.id}", params: { user: { role: "kitchen" } }
      expect(response).to redirect_to("/users")
      expect(reload_user(target)).to be_kitchen
    end

    it "lets the owner edit settings" do
      login_as owner, scope: :user

      get "/settings/edit"
      expect(response).to have_http_status(:ok)

      patch "/settings", params: { business: { name: "Renamed" } }
      expect(response).to redirect_to("/settings/edit")
      expect(business.reload.name).to eq("Renamed")
    end

    it "forbids the cashier from managing users" do
      login_as cashier, scope: :user

      get "/users"
      expect(response).to have_http_status(:forbidden)

      get "/users/new"
      expect(response).to have_http_status(:forbidden)

      post "/users", params: { user: { name: "Intruder", email: "intruder@example.test", role: "owner", password: "password123" } }
      expect(response).to have_http_status(:forbidden)
      expect(User.unscoped.where(email: "intruder@example.test")).to be_empty
    end

    it "forbids the kitchen from managing users or settings" do
      login_as kitchen, scope: :user

      get "/users"
      expect(response).to have_http_status(:forbidden)

      get "/settings/edit"
      expect(response).to have_http_status(:forbidden)

      patch "/settings", params: { business: { name: "Hacked" } }
      expect(response).to have_http_status(:forbidden)
      expect(business.reload.name).not_to eq("Hacked")
    end

    it "forbids a cashier from editing other users" do
      login_as cashier, scope: :user
      target = Tenancy.with_business(business) { create(:user, :kitchen, business: business) }

      get "/users/#{target.id}/edit"
      expect(response).to have_http_status(:forbidden)

      patch "/users/#{target.id}", params: { user: { role: "owner" } }
      expect(response).to have_http_status(:forbidden)
      expect(reload_user(target)).to be_kitchen
    end
  end

  describe "validation failures" do
    it "re-renders the user form when creation fails" do
      login_as owner, scope: :user

      post "/users", params: { user: { name: "", email: "invalid@example.test", role: "cashier", password: "password123" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "re-renders the user form when update fails" do
      login_as owner, scope: :user
      target = Tenancy.with_business(business) { create(:user, :cashier, business: business) }

      patch "/users/#{target.id}", params: { user: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(reload_user(target).name).not_to be_empty
    end

    it "re-renders the settings form when update fails" do
      login_as owner, scope: :user

      patch "/settings", params: { business: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(business.reload.name).not_to be_empty
    end
  end

  describe "JSON responses" do
    it "returns 403 for forbidden JSON requests" do
      login_as cashier, scope: :user

      get "/users.json"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
