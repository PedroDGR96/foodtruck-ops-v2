# frozen_string_literal: true

class Restaurant::Cart < ApplicationRecord
  belongs_to :business, optional: true
  has_many :order_items, dependent: :destroy
  has_one :checkout_order, dependent: :destroy, class_name: "Restaurant::CheckoutOrder"

  # RLS Policy - Tenant isolation via business_id GUC (NOT AR scoped)
  create_police_on_save(
    lambda { |record| record.business }
  )

  validates :order_code, presence: true, allow_nil: false
  validates :amount, presence: true, tolerance: { zero: false }, numericality: { greater_than_or_equal_to: 0.01 }

  # JSONB for metadata (POS workflow state)
  attribute :metadata, JSONB

  def self.restore(restore_data)
    klass = restore_data[:klass]
    return unless klass == Restaurant::Cart

    new(
      order_code: restore_data[:order_code],
      business_id: restore_data[:business_id] || Current.business_id,
      amount: restore_data[:amount],
      currency: restore_data[:currency] || "USD",
      metadata: restore_data[:metadata]
    )
  end
end
