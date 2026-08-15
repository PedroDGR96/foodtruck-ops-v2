# Builds the POS-facing menu: available products grouped by active category,
# with an optional fast name search. Results are cached with a tenant-aware key
# that includes the business menu version, which is bumped on every menu write
# (see MenuInvalidatable), and the search term.
class MenuQuery
  def self.call(business:, query: "", eager_load: true)
    new(business, query, eager_load).call
  end

  def initialize(business, query, eager_load = true)
    @business = business
    @query = query.to_s.strip
    @eager_load = eager_load
  end

  def call
    Tenancy.with_business(business) { Rails.cache.fetch(cache_key) { build_menu } }
  end

  private

  attr_reader :business, :query, :eager_load

  def cache_key
    version = Business.where(id: business.id).pick(:menu_version) || 0
    [ "menu", business.id, version, query, eager_load ]
  end

  def build_menu
    products = Product.available.ordered
      .where(category: business.categories.active)
    products = products.includes(:product_addon_groups, :product_variants, image_attachment: :blob) if eager_load
    products = products.where("products.name ILIKE ?", "%#{sanitize_like(query)}%") if query.present?

    categories = business.categories.active.where(id: products.select(:category_id)).ordered
    categories.map do |category|
      [ category, products.select { |product| product.category_id == category.id } ]
    end
  end

  def sanitize_like(term)
    ActiveRecord::Base.sanitize_sql_like(term)
  end
end
