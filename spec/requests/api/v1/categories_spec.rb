require "swagger_helper"

RSpec.describe "API v1 Categories", type: :request do
  let(:business) { create(:business) }
  let(:user) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:token) { api_token_for(user, scope: "writer") }
  let(:Authorization) { "Bearer #{token}" }

  path "/api/v1/categories" do
    get "Lists categories" do
      tags "Categories"
      security [ { bearerAuth: [] } ]
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      let(:page) { 1 }
      let(:per_page) { 25 }

      response "200", "categories found" do
        before do
          Tenancy.with_business(business) { create(:category, name: "Lanches", business: business) }
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["data"].length).to eq(1)
          expect(body["data"].first["name"]).to eq("Lanches")
          expect(response.headers["X-Total-Count"]).to eq("1")
          expect(response.headers["X-Page"]).to eq("1")
        end
      end

      response "401", "invalid token" do
        let(:Authorization) { "Bearer invalid-token" }
        run_test!
      end
    end

    post "Creates a category" do
      tags "Categories"
      security [ { bearerAuth: [] } ]
      parameter name: :category, in: :body,
                schema: { type: :object, properties: { name: { type: :string } }, required: [ "name" ] }

      let(:category) { { name: "Bebidas" } }

      response "201", "category created" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["name"]).to eq("Bebidas")
        end
      end

      response "403", "read-only scope" do
        let(:token) { api_token_for(user, scope: "reader") }
        run_test!
      end

      response "400", "missing category payload" do
        let(:category) { nil }
        run_test!
      end

      response "422", "invalid category" do
        let(:category) { { name: "" } }
        run_test!
      end
    end
  end

  path "/api/v1/categories/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    let(:record) { Tenancy.with_business(business) { create(:category, name: "Lanches", business: business) } }
    let(:id) { record.id }

    get "Shows a category" do
      tags "Categories"
      security [ { bearerAuth: [] } ]

      response "200", "category found" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["id"]).to eq(id)
        end
      end

      response "404", "cross-tenant or missing category" do
        let(:other_business) { create(:business) }
        let(:id) { Tenancy.with_business(other_business) { create(:category, business: other_business) }.id }
        run_test!
      end
    end

    patch "Updates a category" do
      tags "Categories"
      security [ { bearerAuth: [] } ]
      parameter name: :category, in: :body,
                schema: { type: :object, properties: { name: { type: :string } } }

      let(:category) { { name: "Renomeada" } }

      response "200", "category updated" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["name"]).to eq("Renomeada")
        end
      end

      response "403", "read-only scope" do
        let(:token) { api_token_for(user, scope: "reader") }
        run_test!
      end
    end
  end
end
