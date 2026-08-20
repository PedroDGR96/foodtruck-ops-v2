require "rails_helper"

RSpec.describe MenuQuery, type: :service do
  let(:business) { create(:business) }

  def with_business(&block)
    Tenancy.with_business(business, &block)
  end

  before do
    Rails.cache.clear
    with_business { create(:category, business: business, name: "Lanches", position: 1) }
    with_business { create(:category, business: business, name: "Bebidas", position: 2) }
  end

  it "groups available products by active category in order" do
    lanches = with_business { Category.find_by(name: "Lanches") }
    bebidas = with_business { Category.find_by(name: "Bebidas") }
    with_business { create(:product, business: business, category: lanches, name: "X-Burger", price: 15.5) }
    with_business { create(:product, business: business, category: bebidas, name: "Suco", price: 6.0) }

    menu = MenuQuery.call(business: business)
    names = menu.flat_map { |_category, products| products.map(&:name) }

    expect(names).to eq([ "X-Burger", "Suco" ])
    expect(menu.map(&:first).map(&:name)).to eq(%w[Lanches Bebidas])
  end

  it "hides unavailable products" do
    lanches = with_business { Category.find_by(name: "Lanches") }
    with_business { create(:product, business: business, category: lanches, name: "X-Burger", status: "unavailable") }

    expect(MenuQuery.call(business: business)).to be_empty
  end

  it "hides products in inactive categories" do
    lanches = with_business { Category.find_by(name: "Lanches") }
    bebidas = with_business { Category.find_by(name: "Bebidas") }
    with_business { create(:product, business: business, category: lanches, name: "X-Burger") }
    with_business { create(:product, business: business, category: bebidas, name: "Suco") }
    with_business { lanches.update!(active: false) }

    menu = MenuQuery.call(business: business)
    expect(menu.map(&:first).map(&:name)).to eq(%w[Bebidas])
  end

  it "filters by name search" do
    lanches = with_business { Category.find_by(name: "Lanches") }
    with_business { create(:product, business: business, category: lanches, name: "X-Burger") }
    with_business { create(:product, business: business, category: lanches, name: "X-Burger Bacon") }
    with_business { create(:product, business: business, category: lanches, name: "Coxinha") }

    menu = MenuQuery.call(business: business, query: "burger")
    expect(menu.flat_map { |_c, products| products.map(&:name) }).to contain_exactly("X-Burger", "X-Burger Bacon")
  end

  it "escapes LIKE wildcards in the search term" do
    lanches = with_business { Category.find_by(name: "Lanches") }
    with_business { create(:product, business: business, category: lanches, name: "Promo 100%") }
    with_business { create(:product, business: business, category: lanches, name: "Promo 100") }
    with_business { create(:product, business: business, category: lanches, name: "A_sa") }

    expect(MenuQuery.call(business: business, query: "100%").flat_map { |_c, products| products.map(&:name) })
      .to contain_exactly("Promo 100%")
    expect(MenuQuery.call(business: business, query: "A_sa").flat_map { |_c, products| products.map(&:name) })
      .to contain_exactly("A_sa")
  end

  it "invalidates the cached menu when a menu record changes" do
    lanches = with_business { Category.find_by(name: "Lanches") }
    with_business { create(:product, business: business, category: lanches, name: "X-Burger") }

    expect(MenuQuery.call(business: business).flat_map { |_c, products| products.map(&:name) }).to eq([ "X-Burger" ])

    with_business { create(:product, business: business, category: lanches, name: "Coxinha") }

    menu = MenuQuery.call(business: business)
    expect(menu.flat_map { |_c, products| products.map(&:name) }).to contain_exactly("X-Burger", "Coxinha")
  end

  it "invalidates the cached menu when a product is discarded" do
    lanches = with_business { Category.find_by(name: "Lanches") }
    product = with_business { create(:product, business: business, category: lanches, name: "X-Burger") }
    expect(MenuQuery.call(business: business)).not_to be_empty

    with_business { product.discard! }

    expect(MenuQuery.call(business: business)).to be_empty
  end

  it "keeps menus for different businesses isolated" do
    lanches = with_business { Category.find_by(name: "Lanches") }
    with_business { create(:product, business: business, category: lanches, name: "X-Burger") }

    other = create(:business)
    Tenancy.with_business(other) do
      other_category = create(:category, business: other, name: "Cafés")
      create(:product, business: other, category: other_category, name: "Expresso")
    end

    own_names = MenuQuery.call(business: business).flat_map { |_c, products| products.map(&:name) }
    other_names = MenuQuery.call(business: other).flat_map { |_c, products| products.map(&:name) }

    expect(own_names).to eq([ "X-Burger" ])
    expect(other_names).to eq([ "Expresso" ])
  end
end
