class ProductVariant < ApplicationRecord
  include BusinessScoped
  include SoftDelete
  include MenuInvalidatable
  include TenantChild

  belongs_to :product

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates_parent_business_for :product

  scope :ordered, -> { order(:name) }

  def effective_price
    price.presence || product&.price
  end
end
