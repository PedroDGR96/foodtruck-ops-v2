require "swagger_helper"

RSpec.describe "API v1 Cash Registers", type: :request do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }
  let(:token) { api_token_for(owner, scope: "writer") }
  let(:Authorization) { "Bearer #{token}" }

  path "/api/v1/cash_registers" do
    get "Lists cash register shifts" do
      tags "Cash Registers"
      security [ { bearerAuth: [] } ]

      response "200", "shifts found" do
        before do
          Tenancy.with_business(business) { create(:cash_register, :open, business: business) }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)["data"].length).to eq(1)
        end
      end

      response "401", "invalid token" do
        let(:Authorization) { "Bearer invalid-token" }
        run_test!
      end
    end

    post "Opens a cash register shift" do
      tags "Cash Registers"
      security [ { bearerAuth: [] } ]
      parameter name: :cash_register, in: :body,
                schema: { type: :object, properties: { opening_amount: { type: :number } },
                          required: [ "opening_amount" ] }

      let(:cash_register) { { opening_amount: 100.0 } }

      response "201", "shift opened" do
        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["data"]["status"]).to eq("open")
          expect(body["data"]["opening_amount"].to_f).to eq(100.0)
        end
      end

      response "403", "read-only scope" do
        let(:token) { api_token_for(owner, scope: "reader") }
        run_test!
      end

      response "422", "invalid opening amount" do
        let(:cash_register) { { opening_amount: -5 } }
        run_test!
      end
    end
  end

  path "/api/v1/cash_registers/active" do
    get "Shows the active shift" do
      tags "Cash Registers"
      security [ { bearerAuth: [] } ]

      response "200", "active shift found" do
        before do
          Tenancy.with_business(business) { create(:cash_register, :open, business: business) }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["status"]).to eq("open")
        end
      end

      response "404", "no active shift" do
        run_test!
      end
    end
  end

  path "/api/v1/cash_registers/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    let(:register) { Tenancy.with_business(business) { create(:cash_register, :open, business: business) } }
    let(:id) { register.id }

    get "Shows a shift" do
      tags "Cash Registers"
      security [ { bearerAuth: [] } ]

      response "200", "shift found" do
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["id"]).to eq(id)
        end
      end

      response "404", "cross-tenant or missing shift" do
        let(:other_business) { create(:business) }
        let(:id) { Tenancy.with_business(other_business) { create(:cash_register, business: other_business) }.id }
        run_test!
      end
    end
  end

  path "/api/v1/cash_registers/{id}/close" do
    parameter name: :id, in: :path, type: :string, required: true
    parameter name: :actual_closing_amount, in: :query, type: :number, required: false

    let(:register) { Tenancy.with_business(business) { create(:cash_register, :open, business: business) } }
    let(:id) { register.id }

    post "Closes a shift" do
      tags "Cash Registers"
      security [ { bearerAuth: [] } ]

      response "200", "shift closed" do
        let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
        let(:register) do
          Tenancy.with_business(business) { create(:cash_register, :open, business: business, user: cashier) }
        end
        let(:token) { api_token_for(cashier, scope: "writer") }
        let(:actual_closing_amount) { 100.0 }
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["status"]).to eq("closed")
        end
      end

      response "403", "not the shift's cashier" do
        let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
        let(:other_cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
        let(:register) do
          Tenancy.with_business(business) { create(:cash_register, :open, business: business, user: cashier) }
        end
        let(:token) { api_token_for(other_cashier, scope: "writer") }
        let(:actual_closing_amount) { 100.0 }
        run_test!
      end

      response "422", "shift already closed" do
        let(:register) { Tenancy.with_business(business) { create(:cash_register, :closed, business: business) } }
        let(:actual_closing_amount) { 100.0 }
        run_test!
      end
    end
  end
end
