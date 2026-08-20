class Category < ApplicationRecord
  include BusinessScoped
  include SoftDelete
  include MenuInvalidatable

  has_many :products, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :name, uniqueness: { scope: :business_id }

  scope :ordered, -> { order(:position, :name) }
  scope :active, -> { where(active: true) }
end
