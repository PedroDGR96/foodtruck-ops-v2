class Product < ApplicationRecord
  include BusinessScoped
  include SoftDelete
  include MenuInvalidatable
  include TenantChild

  enum :status, { available: "available", unavailable: "unavailable" }

  belongs_to :category
  has_one_attached :image
  has_many :product_variants, dependent: :restrict_with_exception
  has_many :product_addon_groups, dependent: :restrict_with_exception
  has_many :product_addons, through: :product_addon_groups

  validates :name, presence: true
  validates :name, uniqueness: { scope: :business_id }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates_parent_business_for :category

  scope :ordered, -> { order(:position, :name) }
  scope :available, -> { where(status: :available) }
  scope :with_attachments, -> { includes(image_attachment: :blob) }
end
