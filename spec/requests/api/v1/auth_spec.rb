require "rails_helper"

RSpec.describe "API v1 authentication", type: :request do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }

  it "rejects requests without a token" do
    get "/api/v1/categories"

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects requests with an invalid token" do
    get "/api/v1/categories", headers: { "Authorization" => "Bearer not-a-token" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects expired tokens" do
    raw = api_token_for(owner)
    Token.find_by(token_digest: Token.digest(raw)).update_column(:expires_at, 1.hour.ago)

    get "/api/v1/categories", headers: { "Authorization" => "Bearer #{raw}" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects inactive tokens" do
    raw = api_token_for(owner)
    Token.find_by(token_digest: Token.digest(raw)).update_column(:active, false)

    get "/api/v1/categories", headers: { "Authorization" => "Bearer #{raw}" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "forbids kitchen users from creating menu records" do
    kitchen = Tenancy.with_business(business) { create(:user, :kitchen, business: business) }
    raw = api_token_for(kitchen, scope: "writer")

    post "/api/v1/categories", params: { category: { name: "Sobremesas" } },
         headers: { "Authorization" => "Bearer #{raw}" }

    expect(response).to have_http_status(:forbidden)
  end

  it "clamps pagination params and reports pagination headers" do
    Tenancy.with_business(business) { create_list(:category, 3, business: business) }
    raw = api_token_for(owner, scope: "reader")

    get "/api/v1/categories", params: { page: 0, per_page: 500 },
        headers: { "Authorization" => "Bearer #{raw}" }

    expect(response).to have_http_status(:ok)
    expect(response.headers["X-Page"]).to eq("1")
    expect(response.headers["X-Per-Page"]).to eq("100")
    expect(response.headers["X-Total-Count"]).to eq("3")
    expect(response.headers["X-Total-Pages"]).to eq("1")
  end
end
