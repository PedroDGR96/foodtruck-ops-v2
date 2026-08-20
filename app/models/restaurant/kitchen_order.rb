# frozen_string_literal: true

require "active_record"
require_relative "../../config/database"

class Restaurant::KitchenOrder < ApplicationRecord
  belongs_to :order, class_name: "Restaurant::Order", optional: true
  belongs_to :business, optional: true

  # RLS Policy - Tenant isolation via business_id GUC (NOT AR scoped)
  create_police_on_save(
    lambda { |record| record.business }
  )

  validates :order_code, presence: true, allow_nil: false
  validates :status, inclusion: %w[pending cooking ready_for_pickup ready sold_out], allowed_values: true

  # JSONB for metadata
  attribute :metadata, JSONB

  def self.restore(restore_data)
    klass = restore_data[:klass]
    return unless klass == Restaurant::KitchenOrder

    new(
      order_id: restore_data[:order_id],
      business_id: restore_data[:business_id] || Current.business_id,
      order_code: restore_data[:order_code],
      status: restore_data[:status] || "pending",
      metadata: restore_data[:metadata]
    )
  end
end
