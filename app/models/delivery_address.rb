class DeliveryAddress < ApplicationRecord
  include BusinessScoped
  include TenantChild

  belongs_to :order

  validates :street, :city, :state, presence: true
  validates_parent_business_for :order
end
