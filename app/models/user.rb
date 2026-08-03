class User < ApplicationRecord
  include BusinessScoped

  ROLES = %w[owner cashier kitchen].freeze

  validates :email, presence: true, uniqueness: { scope: :business_id }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
end
