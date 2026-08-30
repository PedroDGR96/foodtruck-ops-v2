# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Privacy", type: :request do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }

  it "renders the privacy policy with the current business name" do
    login_as owner, scope: :user
    get "/privacy"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(business.name)
  end
end
