class ProductAddon < ApplicationRecord
  include BusinessScoped
  include SoftDelete
  include MenuInvalidatable
  include TenantChild

  belongs_to :product_addon_group

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates_parent_business_for :product_addon_group

  scope :ordered, -> { order(:name) }
end
