class Delivery < ApplicationRecord
  include BusinessScoped
  include TenantChild

  enum :status, { pending: "pending", out_for_delivery: "out_for_delivery", delivered: "delivered" }, default: :pending

  belongs_to :order

  validates_parent_business_for :order
end
