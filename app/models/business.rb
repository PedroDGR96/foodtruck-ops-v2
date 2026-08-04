class Business < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :categories, dependent: :restrict_with_exception
  has_many :products, dependent: :restrict_with_exception
  has_many :product_variants, through: :products
  has_many :product_addon_groups, through: :products
  has_many :product_addons, through: :product_addon_groups

  validates :name, :currency, :timezone, presence: true
end
