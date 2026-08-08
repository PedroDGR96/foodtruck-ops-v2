require "swagger_helper"

RSpec.describe "API v1 Customers", type: :request do
  let(:business) { create(:business) }
  let(:user) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:token) { api_token_for(user, scope: "writer") }
  let(:Authorization) { "Bearer #{token}" }

  path "/api/v1/customers" do
    get "Lists customers" do
      tags "Customers"
      security [ { bearerAuth: [] } ]

      response "200", "customers found" do
        before do
          Tenancy.with_business(business) { create(:customer, name: "Maria", business: business) }
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["data"].length).to eq(1)
          expect(body["data"].first["name"]).to eq("Maria")
        end
      end

      response "401", "invalid token" do
        let(:Authorization) { "Bearer invalid-token" }
        run_test!
      end
    end

    post "Creates a customer" do
      tags "Customers"
      security [ { bearerAuth: [] } ]
      parameter name: :customer, in: :body,
                schema: { type: :object, properties: { name: { type: :string } }, required: [ "name" ] }

      let(:customer) { { name: "João", phone: "11988887777" } }

      response "201", "customer created" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["name"]).to eq("João")
        end
      end

      response "403", "read-only scope" do
        let(:token) { api_token_for(user, scope: "reader") }
        run_test!
      end

      response "422", "invalid customer" do
        let(:customer) { { name: "Maria", phone: "12345" } }
        run_test!
      end
    end
  end

  path "/api/v1/customers/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    let(:record) { Tenancy.with_business(business) { create(:customer, name: "Maria", business: business) } }
    let(:id) { record.id }

    get "Shows a customer" do
      tags "Customers"
      security [ { bearerAuth: [] } ]

      response "200", "customer found" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["id"]).to eq(id)
        end
      end

      response "404", "cross-tenant or missing customer" do
        let(:other_business) { create(:business) }
        let(:id) { Tenancy.with_business(other_business) { create(:customer, business: other_business) }.id }
        run_test!
      end
    end

    patch "Updates a customer" do
      tags "Customers"
      security [ { bearerAuth: [] } ]
      parameter name: :customer, in: :body,
                schema: { type: :object, properties: { notes: { type: :string } } }

      let(:customer) { { notes: "Cliente VIP" } }

      response "200", "customer updated" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["notes"]).to eq("Cliente VIP")
        end
      end

      response "403", "read-only scope" do
        let(:token) { api_token_for(user, scope: "reader") }
        run_test!
      end
    end
  end
end
