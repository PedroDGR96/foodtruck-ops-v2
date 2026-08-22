class ProductAddonGroup < ApplicationRecord
  include BusinessScoped
  include SoftDelete
  include MenuInvalidatable
  include TenantChild

  belongs_to :product
  has_many :product_addons, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :min_select, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_select, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :max_select_at_least_min_select
  validates_parent_business_for :product

  scope :ordered, -> { order(:position, :name) }

  private

  def max_select_at_least_min_select
    return if max_select.nil? || min_select.nil? || max_select >= min_select

    errors.add(:max_select, :greater_than_or_equal_to, count: min_select)
  end
end
