require "rails_helper"

RSpec.describe "Query budgets", type: :request do
  let(:business) { create(:business) }
  let!(:budget) { 5 }

  before do
    Rails.cache.clear
  end

  def count_queries(&block)
    count = 0
    ActiveSupport::Notifications.subscribed(->(*args) { count += 1 }, "sql.active_record") do
      block.call
    end
    count
  end

  it "menu show stays under the query budget" do
    category = Tenancy.with_business(business) do
      create(:category, business: business, name: "Lanches", position: 1)
    end
    product = Tenancy.with_business(business) do
      create(:product, business: business, category: category, name: "X-Burger")
    end

    queries = count_queries do
      get "/menu"
    end

    expect(queries).to be <= budget
  end

  it "order show stays under the query budget" do
    order = Tenancy.with_business(business) do
      create(:order, business: business)
    end

    queries = count_queries do
      get "/orders/#{order.id}"
    end

    expect(queries).to be <= budget
  end

  it "kitchen board stays under the query budget" do
    Tenancy.with_business(business) do
      create(:order, business: business)
    end

    queries = count_queries do
      get "/kitchen/board"
    end

    expect(queries).to be <= budget
  end
end
