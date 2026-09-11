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

  it "menu show stays under the query budget with multiple products (N+1 guard)" do
    category = Tenancy.with_business(business) do
      create(:category, business: business, name: "Lanches", position: 1)
    end

    3.times do |i|
      Tenancy.with_business(business) do
        create(:product, business: business, category: category, name: "X-Burger #{i + 1}")
      end
    end

    queries = count_queries do
      get "/menu"
    end

    expect(queries).to be <= budget
  end

  it "menu show does not grow unbounded with additional products (N+1 guard)" do
    category_a = Tenancy.with_business(business) do
      create(:category, business: business, name: "Lanches", position: 1)
    end
    category_b = Tenancy.with_business(business) do
      create(:category, business: business, name: "Bebidas", position: 2)
    end

    [category_a, category_b].each_with_index do |cat, i|
      Tenancy.with_business(business) do
        create(:product, business: business, category: cat, name: "Item #{i}")
      end
    end

    baseline = count_queries { get "/menu" }

    Tenancy.with_business(business) do
      create(:product, business: business, category: category_a, name: "Extra Item")
    end

    after = count_queries { get "/menu" }

    expect(after).to be <= budget
  end
end
