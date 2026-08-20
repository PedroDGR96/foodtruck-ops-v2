# frozen_string_literal: true

class Restaurant::CashRegister < ApplicationRecord
  belongs_to :business, optional: true
  has_many :payment_history, dependent: :destroy

  # RLS Policy - Tenant isolation via business_id GUC (NOT AR scoped)
  create_police_on_save(
    lambda { |record| record.business }
  )

  validates :transaction_code, uniqueness: { case_sensitive: true }, allow_nil: false
  validates :amount, presence: true, tolerance: { zero: false }, numericality: { greater_than_or_equal_to: 0.01 }

  # Status mapping for reconciliation
  enum status: {
    completed: "completed",
    refunded: "refunded"
  } unless defined?(enum)

  def self.restore(restore_data)
    klass = restore_data[:klass]
    return unless klass == Restaurant::CashRegister

    new(
      transaction_code: restore_data[:transaction_code],
      business_id: restore_data[:business_id] || Current.business_id,
      amount: restore_data[:amount],
      currency: restore_data[:currency] || "USD",
      status: restore_data[:status] || "completed",
      payment_method: restore_data[:payment_method] || "cash"
    )
  end
end
