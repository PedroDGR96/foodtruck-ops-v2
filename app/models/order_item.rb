class OrderItem < ApplicationRecord
  include BusinessScoped
  include TenantChild

  belongs_to :order
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  has_many :order_item_addons, dependent: :destroy, autosave: true

  validates :product_name, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates_parent_business_for :order, :product, :product_variant

  before_save :set_line_total
  after_save :refresh_order_totals
  after_destroy :refresh_order_totals

  def addons_total
    if persisted?
      order_item_addons.sum(:price)
    else
      order_item_addons.to_a.sum(&:price)
    end
  end

  def unit_total
    (unit_price + addons_total).round(2)
  end

  def set_line_total
    self.line_total = (unit_total * quantity).round(2)
  end

  def refresh_order_totals
    order&.recalculate_totals!
  end

  # Refreshes the stored line total after an add-on changes, then recomputes
  # the order totals. Uses update_columns to avoid recursion.
  def refresh_line_total!
    new_line_total = (unit_total * quantity).round(2)
    update_columns(line_total: new_line_total) if persisted? && line_total != new_line_total
    order&.recalculate_totals!
  end
end
