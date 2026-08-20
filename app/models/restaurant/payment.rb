# frozen_string_literal: true

class Restaurant::Payment < ApplicationRecord
  belongs_to :order, class_name: "Restaurant::Order", optional: true
  belongs_to :business, optional: true

  # RLS Policy - Tenant isolation via business_id GUC (NOT AR scoped)
  create_police_on_save(
    lambda { |record| record.business }
  )

  validates :order_code, presence: true, allow_nil: false
  validates :amount, presence: true, tolerance: { zero: false }, numericality: { greater_than_or_equal_to: 0.01 }
  validates :transaction_code, uniqueness: { case_sensitive: true }, allow_nil: false

  # Status mapping for reconciliation
  enum status: {
    completed: "completed",
    failed: "failed",
    refunded: "refunded"
  } unless defined?(enum)

  def self.restore(restore_data)
    klass = restore_data[:klass]
    return unless klass == Restaurant::Payment

    new(
      order_id: restore_data[:order_id],
      business_id: restore_data[:business_id] || Current.business_id,
      amount: restore_data[:amount],
      currency: restore_data[:currency] || "USD",
      status: restore_data[:status] || "completed",
      transaction_code: restore_data[:transaction_code]
    )
  end
end
