require "rails_helper"

RSpec.describe "Menu management (owner)", type: :request do
  let(:business) { create(:business) }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }

  before { login_as owner, scope: :user }

  def with_tenancy(&block)
    Tenancy.with_business(business, &block)
  end

  describe "categories" do
    let(:category) { with_tenancy { create(:category, business: business, name: "Lanches", position: 2) } }

    it "lists, renders, creates, edits, updates and discards categories" do
      get "/categories"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Lanches")

      get "/categories/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nova")

      post "/categories", params: { category: { name: "Bebidas", position: 1, active: "1" } }
      expect(response).to redirect_to(categories_path)
      expect(with_tenancy { Category.find_by(name: "Bebidas") }).to be_present

      get edit_category_path(category)
      expect(response).to have_http_status(:ok)

      patch category_path(category), params: { category: { name: "Lanches Premium", position: 1 } }
      expect(response).to redirect_to(categories_path)
      expect(with_tenancy { category.reload.name }).to eq("Lanches Premium")

      delete category_path(category)
      expect(response).to redirect_to(categories_path)
      expect(with_tenancy { category.reload.discarded? }).to be(true)
    end

    it "re-renders new and edit on invalid submissions" do
      post "/categories", params: { category: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Nova")

      patch category_path(category), params: { category: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Editar")
    end
  end

  describe "products" do
    let(:category) { with_tenancy { create(:category, business: business, name: "Lanches") } }
    let(:product) { with_tenancy { create(:product, business: business, category: category, name: "X-Burger") } }

    it "lists, renders, creates, shows, edits, updates and discards products" do
      product
      get "/products"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("X-Burger")

      get "/products/new"
      expect(response).to have_http_status(:ok)

      post "/products", params: {
        product: { name: "Coxinha", price: "4.00", status: "available", position: 1, category_id: category.id }
      }
      created = with_tenancy { Product.find_by(name: "Coxinha") }
      expect(response).to redirect_to(product_path(created))

      get product_path(product)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("X-Burger")

      get edit_product_path(product)
      expect(response).to have_http_status(:ok)

      patch product_path(product), params: { product: { name: "X-Burger Duplo", price: "16.00" } }
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { product.reload.name }).to eq("X-Burger Duplo")

      delete product_path(product)
      expect(response).to redirect_to(products_path)
      expect(with_tenancy { product.reload.discarded? }).to be(true)
    end

    it "re-renders new and edit on invalid submissions" do
      post "/products", params: { product: { name: "", category_id: category.id } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Novo")

      patch product_path(product), params: { product: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Editar")
    end
  end

  describe "product variants" do
    let(:category) { with_tenancy { create(:category, business: business, name: "Lanches") } }
    let(:product) { with_tenancy { create(:product, business: business, category: category, name: "X-Burger") } }
    let(:variant) { with_tenancy { create(:product_variant, business: business, product: product, name: "Duplo") } }

    it "renders, creates, edits, updates and discards variants" do
      get new_product_product_variant_path(product)
      expect(response).to have_http_status(:ok)

      post product_product_variants_path(product), params: { product_variant: { name: "Triplo", price: "4.00", active: "1" } }
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { product.product_variants.pluck(:name) }).to include("Triplo")

      get edit_product_product_variant_path(product, variant)
      expect(response).to have_http_status(:ok)

      patch product_product_variant_path(product, variant), params: { product_variant: { name: "Duplo Bacon", price: "5.00" } }
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { variant.reload.name }).to eq("Duplo Bacon")

      delete product_product_variant_path(product, variant)
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { variant.reload.discarded? }).to be(true)
    end

    it "re-renders new and edit on invalid submissions" do
      post product_product_variants_path(product), params: { product_variant: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Nova variação")

      patch product_product_variant_path(product, variant), params: { product_variant: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Editar")
    end
  end

  describe "product add-on groups" do
    let(:category) { with_tenancy { create(:category, business: business, name: "Lanches") } }
    let(:product) { with_tenancy { create(:product, business: business, category: category, name: "X-Burger") } }
    let(:group) { with_tenancy { create(:product_addon_group, business: business, product: product, name: "Adicionais") } }

    it "renders, creates, edits, updates and discards add-on groups" do
      get new_product_product_addon_group_path(product)
      expect(response).to have_http_status(:ok)

      post product_product_addon_groups_path(product), params: {
        product_addon_group: { name: "Molhos", multiple: "1", min_select: "0", max_select: "2", position: 1, active: "1" }
      }
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { product.product_addon_groups.pluck(:name) }).to include("Molhos")

      get edit_product_product_addon_group_path(product, group)
      expect(response).to have_http_status(:ok)

      patch product_product_addon_group_path(product, group), params: { product_addon_group: { name: "Adicionais e Molhos" } }
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { group.reload.name }).to eq("Adicionais e Molhos")

      delete product_product_addon_group_path(product, group)
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { group.reload.discarded? }).to be(true)
    end

    it "re-renders new and edit on invalid submissions" do
      post product_product_addon_groups_path(product), params: { product_addon_group: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Novo")

      patch product_product_addon_group_path(product, group), params: { product_addon_group: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Editar")
    end
  end

  describe "product add-ons" do
    let(:category) { with_tenancy { create(:category, business: business, name: "Lanches") } }
    let(:product) { with_tenancy { create(:product, business: business, category: category, name: "X-Burger") } }
    let(:group) { with_tenancy { create(:product_addon_group, business: business, product: product, name: "Adicionais") } }
    let(:addon) { with_tenancy { create(:product_addon, business: business, product_addon_group: group, name: "Bacon") } }

    it "renders, creates, edits, updates and discards add-ons" do
      get new_product_product_addon_group_product_addon_path(product, group)
      expect(response).to have_http_status(:ok)

      post product_product_addon_group_product_addons_path(product, group), params: {
        product_addon: { name: "Queijo", price: "2.00", active: "1" }
      }
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { group.product_addons.pluck(:name) }).to include("Queijo")

      get edit_product_product_addon_group_product_addon_path(product, group, addon)
      expect(response).to have_http_status(:ok)

      patch product_product_addon_group_product_addon_path(product, group, addon), params: { product_addon: { name: "Bacon Extra", price: "3.00" } }
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { addon.reload.name }).to eq("Bacon Extra")

      delete product_product_addon_group_product_addon_path(product, group, addon)
      expect(response).to redirect_to(product_path(product))
      expect(with_tenancy { addon.reload.discarded? }).to be(true)
    end

    it "re-renders new and edit on invalid submissions" do
      post product_product_addon_group_product_addons_path(product, group), params: { product_addon: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Novo")

      patch product_product_addon_group_product_addon_path(product, group, addon), params: { product_addon: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Editar")
    end
  end

  describe "authorization" do
    let(:category) { with_tenancy { create(:category, business: business) } }
    let(:product) { with_tenancy { create(:product, business: business, category: category) } }

    %w[cashier kitchen].each do |role|
      it "forbids #{role} from editing the menu" do
        staff = with_tenancy { create(:user, role.to_sym, business: business) }
        login_as staff, scope: :user

        get new_category_path
        expect(response).to have_http_status(:forbidden)
        get edit_category_path(category)
        expect(response).to have_http_status(:forbidden)
        get edit_product_path(product)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "forbids guests from accessing menu management" do
      logout
      get "/categories"
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
