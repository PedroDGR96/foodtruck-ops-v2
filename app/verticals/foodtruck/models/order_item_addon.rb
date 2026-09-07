class OrderItemAddon < ApplicationRecord
  include BusinessScoped
  include TenantChild

  belongs_to :order_item
  belongs_to :product_addon, optional: true

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates_parent_business_for :order_item, :product_addon

  after_save :refresh_parent
  after_destroy :refresh_parent

  private

  def refresh_parent
    order_item&.refresh_line_total!
  end
end
