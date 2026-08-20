require "swagger_helper"

RSpec.describe "API v1 Orders", type: :request do
  let(:business) { create(:business) }
  let(:user) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:token) { api_token_for(user, scope: "writer") }
  let(:Authorization) { "Bearer #{token}" }

  path "/api/v1/orders" do
    get "Lists orders" do
      tags "Orders"
      security [ { bearerAuth: [] } ]
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response "200", "orders found" do
        before do
          Tenancy.with_business(business) { create(:order, :open, business: business) }
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["data"].length).to eq(1)
          expect(body["data"].first["status"]).to eq("open")
        end
      end

      response "401", "invalid token" do
        let(:Authorization) { "Bearer invalid-token" }
        run_test!
      end
    end

    post "Creates an order" do
      tags "Orders"
      security [ { bearerAuth: [] } ]
      parameter name: :order, in: :body,
                schema: { type: :object, properties: { order_type: { type: :string } }, required: [ "order_type" ] }

      let(:order) { { order_type: "local" } }

      response "201", "order created and confirmed" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["status"]).to eq("open")
        end
      end

      response "403", "read-only scope" do
        let(:token) { api_token_for(user, scope: "reader") }
        run_test!
      end

      response "422", "invalid order" do
        let(:order) { { order_type: "delivery" } }
        run_test!
      end
    end
  end

  path "/api/v1/orders/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    let(:record) { Tenancy.with_business(business) { create(:order, :open, business: business) } }
    let(:id) { record.id }

    get "Shows an order" do
      tags "Orders"
      security [ { bearerAuth: [] } ]

      response "200", "order found" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["id"]).to eq(id)
        end
      end

      response "404", "cross-tenant or missing order" do
        let(:other_business) { create(:business) }
        let(:id) { Tenancy.with_business(other_business) { create(:order, business: other_business) }.id }
        run_test!
      end
    end
  end

  path "/api/v1/orders/{id}/cancel" do
    parameter name: :id, in: :path, type: :string, required: true

    let(:order) { Tenancy.with_business(business) { create(:order, :open, business: business) } }
    let(:id) { order.id }

    post "Cancels an order" do
      tags "Orders"
      security [ { bearerAuth: [] } ]

      response "200", "order cancelled" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["status"]).to eq("cancelled")
        end
      end

      response "403", "forbidden for non-owner/cashier" do
        let(:kitchen_user) { Tenancy.with_business(business) { create(:user, :kitchen, business: business) } }
        let(:token) { api_token_for(kitchen_user, scope: "writer") }
        run_test!
      end

      response "422", "illegal transition on a paid order" do
        let(:order) { Tenancy.with_business(business) { create(:order, :paid, business: business) } }
        run_test!
      end
    end
  end

  path "/api/v1/orders/{id}/force_cancel" do
    parameter name: :id, in: :path, type: :string, required: true

    let(:order) { Tenancy.with_business(business) { create(:order, :paid, business: business) } }
    let(:id) { order.id }

    post "Force-cancels an order" do
      tags "Orders"
      security [ { bearerAuth: [] } ]

      response "200", "order force-cancelled" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["status"]).to eq("cancelled")
        end
      end
    end
  end

  path "/api/v1/orders/{id}/refund" do
    parameter name: :id, in: :path, type: :string, required: true

    let(:order) { Tenancy.with_business(business) { create(:order, :partially_paid, business: business) } }
    let(:id) { order.id }

    post "Refunds an order" do
      tags "Orders"
      security [ { bearerAuth: [] } ]

      response "200", "order refunded" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["status"]).to eq("refunded")
        end
      end

      response "422", "illegal transition on a draft order" do
        let(:order) { Tenancy.with_business(business) { create(:order, business: business) } }
        run_test!
      end
    end
  end
end
