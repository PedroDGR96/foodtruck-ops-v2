# frozen_string_literal: true

require "active_record"
require_relative "../../config/database"

class Restaurant::Order < ApplicationRecord
  belongs_to :business, optional: true
  belongs_to :kitchen_order, class_name: "KitchenOrder", optional: true
  has_many :payment_history, dependent: :destroy
  has_many :sync_queues, dependent: :destroy

  # RLS Policy - Tenant isolation via business_id GUC (NOT AR scoped)
  create_police_on_save(
    lambda { |record| record.business }
  )

  validates :order_code, uniqueness: true, allow_nil: false
  validates :amount, presence: true, tolerance: { zero: false }, numericality: { greater_than_or_equal_to: 0.01 }

  # Transient scopes for POS workflow (not persisted)
  scope :pending, -> { where(status: "pending", updated_at: nil) }
  scope :ready_for_pickup, -> { where(status: "ready_for_pickup", updated_at: nil) }
  scope :completed, -> { where(status: "completed") }

  # JSONB column for metadata (for sync)
  attribute :metadata, JSONB

  def self.restore(restore_data)
    klass = restore_data[:klass]
    return unless klass == Restaurant::Order

    new(
      order_code: restore_data[:order_code],
      business_id: restore_data[:business_id] || Current.business_id,
      amount: restore_data[:amount],
      currency: restore_data[:currency] || "USD",
      status: restore_data[:status] || "pending",
      metadata: restore_data[:metadata]
    )
  end
end
