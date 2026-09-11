# frozen_string_literal: true

require "rails_helper"

# Query-budget guards for the three hottest read paths. Each test seeds real
# data and then counts SQL statements inside an ActiveSupport::Notifications
# subscriber so we catch N+1 loads as well as scope regressions.
#
# Strategy: rather than asserting queries <= an arbitrary static constant we
# compare query counts across data sizes. If an N+1 creeps in, adding more
# rows grows the count proportionally — the "scaled" budget will catch that.
#
# The menu response is cached (MenuQuery uses Rails.cache with a tenant-aware
# key). We clear the cache before every request so we always hit the real
# query path.
RSpec.describe "Query budgets", type: :request do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business, email: "qbug-#{SecureRandom.hex(4)}@example.test") } }

  # --- helpers ----------------------------------------------------------------

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  def count_queries(&block)
    count = 0
    callback = ->(*_args) { count += 1 }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { block.call }
    count
  end

  def seed_products(n, category = nil, salt: SecureRandom.hex(3))
    category ||= within_tenant { create(:category, business: business, name: "Qbug Cat #{salt}", position: 1) }
    n.times do |i|
      within_tenant do
        product = create(:product, business: business, category: category, name: "Qbug Item #{salt}-#{i}")
        group = create(:product_addon_group, business: business, product: product, name: "Extras")
        create(:product_addon, business: business, product_addon_group: group, name: "Add #{i}", price: 1.0)
      end
    end
  end

  def seed_order_with_events(count: 3)
    within_tenant do
      order = create(:order, :open, business: business, total: 50.0, subtotal: 50.0)
      count.times { create(:order_event, business: business, order: order) }
      order
    end
  end

  # --- menu -------------------------------------------------------------------

  describe "GET /menu" do
    before { login_as owner, scope: :user }

    it "stays bounded with a single product" do
      seed_products(1)
      Rails.cache.clear

      queries = count_queries { get menu_path }

      expect(queries).to be >= 1, "expected at least 1 query"
      expect(queries).to be <= 30, "single product used #{queries} queries (expect <= 30)"
    end

    it "does not scale queries proportionally with more products (N+1 guard)" do
      seed_products(1)
      Rails.cache.clear
      baseline = count_queries { get menu_path }

      seed_products(4)
      Rails.cache.clear
      after = count_queries { get menu_path }

      # If each product added an independent query, after would be ~5x baseline.
      # Allow 2.5x headroom (covers eager-load + category + caching internals).
      expect(after).to be <= [ baseline * 2.5, baseline + 6 ].max,
        "N+1 suspected: #{baseline} queries with 1 product grew to #{after} with 5"
    end

    it "stays bounded with multiple addon groups per product" do
      category = within_tenant { create(:category, business: business, name: "Addon Cat #{SecureRandom.hex(3)}", position: 1) }
      within_tenant do
        product = create(:product, business: business, category: category, name: "Multi Addon #{SecureRandom.hex(3)}")
        3.times do |j|
          group = create(:product_addon_group, business: business, product: product, name: "G#{j}")
          create(:product_addon, business: business, product_addon_group: group, name: "A#{j}", price: 1.0)
        end
      end
      Rails.cache.clear

      queries = count_queries { get menu_path }

      expect(queries).to be <= 30, "multi-addon product used #{queries} queries (expect <= 30)"
    end
  end

  # --- orders#show -----------------------------------------------------------

  describe "GET /orders/:id" do
    it "stays bounded for an order with several events" do
      order = seed_order_with_events(count: 5)
      login_as owner, scope: :user

      queries = count_queries { get order_path(order) }

      expect(queries).to be >= 1
      expect(queries).to be <= 30, "order show with 5 events used #{queries} queries (expect <= 30)"
    end

    it "does not scale queries with more order events" do
      order_small = seed_order_with_events(count: 1)
      order_large = seed_order_with_events(count: 8)
      login_as owner, scope: :user

      base  = count_queries { get order_path(order_small) }
      large = count_queries { get order_path(order_large) }

      # 8x events should not produce 8x queries
      expect(large).to be <= [ base * 2.5, base + 6 ].max,
        "order events N+1: #{base} queries with 1 event grew to #{large} with 8"
    end
  end

  # --- kitchen#show ----------------------------------------------------------

  describe "GET /kitchen" do
    before do
      within_tenant do
        create(:order, :open, business: business, total: 20.0, subtotal: 20.0)
        create(:order, :open, business: business, total: 30.0, subtotal: 30.0)
      end
      login_as owner, scope: :user
    end

    it "stays bounded with a few orders" do
      queries = count_queries { get kitchen_path }

      expect(queries).to be <= 30, "kitchen board with 2 orders used #{queries} queries (expect <= 30)"
    end

    it "does not scale queries with more orders in the queue" do
      baseline = count_queries { get kitchen_path }

      4.times do |i|
        within_tenant do
          create(:order, :open, business: business, total: 10.0 + i, subtotal: 10.0 + i)
        end
      end

      after = count_queries { get kitchen_path }

      expect(after).to be <= [ baseline * 2.5, baseline + 6 ].max,
        "kitchen N+1: #{baseline} queries with 2 orders grew to #{after} with 6"
    end
  end
end
