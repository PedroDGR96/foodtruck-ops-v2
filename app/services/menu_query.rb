# Builds the POS-facing menu: available products grouped by active category,
# with an optional fast name search. Results are cached with a tenant-aware key
# that includes the business menu version, which is bumped on every menu write
# (see MenuInvalidatable), and the search term.
class MenuQuery
  def self.call(business:, query: "")
    new(business, query).call
  end

  def initialize(business, query)
    @business = business
    @query = query.to_s.strip
  end

  def call
    Tenancy.with_business(business) { Rails.cache.fetch(cache_key) { build_menu } }
  end

  private

  attr_reader :business, :query

  def cache_key
    version = Business.unscoped.where(id: business.id).pick(:menu_version) || 0
    [ "menu", business.id, version, query ]
  end

  def build_menu
    products = Product.available.ordered
      .includes(:product_addon_groups, :product_variants, image_attachment: :blob)
      .where(category: business.categories.active)
    products = products.where("products.name ILIKE ?", "%#{query}%") if query.present?

    categories = business.categories.active.where(id: products.select(:category_id)).ordered
    categories.map do |category|
      [ category, products.select { |product| product.category_id == category.id } ]
    end
  end
end
