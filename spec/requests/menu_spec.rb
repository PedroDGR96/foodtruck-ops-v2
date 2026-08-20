require "rails_helper"

RSpec.describe "Menu management", type: :request do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  let(:owner) { staff(:owner) }
  let(:cashier) { staff(:cashier) }

  describe "owner builds a menu" do
    before { login_as owner, scope: :user }

    it "creates a category, product with variant and add-ons, and shows it in the POS menu" do
      post "/categories", params: { category: { name: "Lanches", position: 1, active: "1" } }
      expect(response).to redirect_to(categories_path)
      category = Tenancy.with_business(business) { Category.find_by(name: "Lanches") }
      expect(category).to be_present

      get "/categories"
      expect(response.body).to include("Lanches")

      post "/products", params: {
        product: { name: "X-Burger", price: "15.50", category_id: category.id, status: "available", position: 0, description: "Pão, carne e queijo" }
      }
      product = Tenancy.with_business(business) { Product.find_by(name: "X-Burger") }
      expect(response).to redirect_to(product_path(product))

      post "/products/#{product.id}/product_variants", params: {
        product_variant: { name: "Duplo", price: "3.00", stock: "", active: "1" }
      }
      expect(response).to redirect_to(product_path(product))
      expect(Tenancy.with_business(business) { product.product_variants.count }).to eq(1)

      post "/products/#{product.id}/product_addon_groups", params: {
        product_addon_group: { name: "Adicionais", multiple: "1", min_select: "0", max_select: "", position: 0, active: "1" }
      }
      expect(response).to redirect_to(product_path(product))
      group = Tenancy.with_business(business) { product.product_addon_groups.first }

      post "/products/#{product.id}/product_addon_groups/#{group.id}/product_addons", params: {
        product_addon: { name: "Bacon", price: "2.50", active: "1" }
      }
      expect(response).to redirect_to(product_path(product))
      expect(Tenancy.with_business(business) { group.product_addons.count }).to eq(1)

      get "/products/#{product.id}"
      expect(response.body).to include("X-Burger")
      expect(response.body).to include("Duplo")
      expect(response.body).to include("Bacon")
      expect(response.body).to include("R$ 15,50")
    end

    it "archives a product so it leaves the POS menu" do
      category = Tenancy.with_business(business) { create(:category, business: business) }
      product = Tenancy.with_business(business) { create(:product, business: business, category: category, name: "Coxinha") }

      delete "/products/#{product.id}"

      expect(response).to redirect_to(products_path)
      expect(Tenancy.with_business(business) { product.reload.discarded? }).to be(true)
    end
  end

  describe "cashier reads the menu" do
    before do
      login_as cashier, scope: :user
      @category = Tenancy.with_business(business) { create(:category, business: business, name: "Bebidas") }
      @product = Tenancy.with_business(business) do
        create(:product, business: business, category: @category, name: "Suco de Laranja", price: 6.0)
      end
    end

    it "sees the menu grouped by category with BRL prices" do
      get "/menu"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bebidas")
      expect(response.body).to include("Suco de Laranja")
      expect(response.body).to include("R$ 6,00")
    end

    it "searches the menu by product name" do
      get "/menu?query=SUCO"

      expect(response.body).to include("Suco de Laranja")
    end

    it "shows an empty state for a search without results" do
      get "/menu?query=nao-existe"

      expect(response.body).to include(I18n.t("menu.empty_search"))
    end
  end

  describe "cashier cannot edit the menu" do
    before { login_as cashier, scope: :user }

    let(:category) { Tenancy.with_business(business) { create(:category, business: business) } }
    let(:product) { Tenancy.with_business(business) { create(:product, business: business, category: category) } }

    it "is forbidden from writing categories" do
      get "/categories/new"
      expect(response).to have_http_status(:forbidden)

      post "/categories", params: { category: { name: "Hack" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "is forbidden from writing products, variants, groups and add-ons" do
      get "/products/new"
      expect(response).to have_http_status(:forbidden)

      post "/products", params: { product: { name: "Hack" } }
      expect(response).to have_http_status(:forbidden)

      post "/products/#{product.id}/product_variants", params: { product_variant: { name: "Hack" } }
      expect(response).to have_http_status(:forbidden)

      post "/products/#{product.id}/product_addon_groups", params: { product_addon_group: { name: "Hack" } }
      expect(response).to have_http_status(:forbidden)

      group = Tenancy.with_business(business) { create(:product_addon_group, business: business, product: product) }
      post "/products/#{product.id}/product_addon_groups/#{group.id}/product_addons", params: { product_addon: { name: "Hack" } }
      expect(response).to have_http_status(:forbidden)

      delete "/categories/#{category.id}"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
