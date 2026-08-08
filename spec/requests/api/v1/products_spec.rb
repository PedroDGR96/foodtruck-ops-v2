require "swagger_helper"

RSpec.describe "API v1 Products", type: :request do
  let(:business) { create(:business) }
  let(:user) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:token) { api_token_for(user, scope: "writer") }
  let(:Authorization) { "Bearer #{token}" }

  path "/api/v1/products" do
    get "Lists products" do
      tags "Products"
      security [ { bearerAuth: [] } ]

      response "200", "products found" do
        before do
          Tenancy.with_business(business) do
            category = create(:category, business: business)
            create(:product, name: "X-Salada", business: business, category: category)
          end
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["data"].length).to eq(1)
          expect(body["data"].first["name"]).to eq("X-Salada")
        end
      end

      response "401", "invalid token" do
        let(:Authorization) { "Bearer invalid-token" }
        run_test!
      end
    end

    post "Creates a product" do
      tags "Products"
      security [ { bearerAuth: [] } ]
      parameter name: :product, in: :body,
                schema: { type: :object, properties: { name: { type: :string }, price: { type: :number } },
                          required: [ "name", "price" ] }

      let(:category) { Tenancy.with_business(business) { create(:category, business: business) } }
      let(:product) { { name: "X-Bacon", price: 20.0, category_id: category.id } }

      response "201", "product created" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["name"]).to eq("X-Bacon")
        end
      end

      response "403", "read-only scope" do
        let(:token) { api_token_for(user, scope: "reader") }
        run_test!
      end

      response "422", "invalid product" do
        let(:product) { { name: "X-Bacon", price: -1 } }
        run_test!
      end
    end
  end

  path "/api/v1/products/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    let(:category) { Tenancy.with_business(business) { create(:category, business: business) } }
    let(:record) do
      Tenancy.with_business(business) { create(:product, name: "X-Salada", business: business, category: category) }
    end
    let(:id) { record.id }

    get "Shows a product" do
      tags "Products"
      security [ { bearerAuth: [] } ]

      response "200", "product found" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["id"]).to eq(id)
        end
      end

      response "404", "cross-tenant or missing product" do
        let(:other_business) { create(:business) }
        let(:id) do
          Tenancy.with_business(other_business) do
            other_category = create(:category, business: other_business)
            create(:product, business: other_business, category: other_category).id
          end
        end
        run_test!
      end
    end

    patch "Updates a product" do
      tags "Products"
      security [ { bearerAuth: [] } ]
      parameter name: :product, in: :body,
                schema: { type: :object, properties: { price: { type: :number } } }

      let(:product) { { price: 15.0 } }

      response "200", "product updated" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["price"].to_f).to eq(15.0)
        end
      end

      response "403", "read-only scope" do
        let(:token) { api_token_for(user, scope: "reader") }
        run_test!
      end
    end
  end
end
