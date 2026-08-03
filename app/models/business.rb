class Business < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception

  validates :name, :currency, :timezone, presence: true
end
