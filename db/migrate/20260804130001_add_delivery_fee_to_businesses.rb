class AddDeliveryFeeToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :delivery_fee, :decimal, precision: 12, scale: 2
    add_check_constraint :businesses, "delivery_fee IS NULL OR delivery_fee >= 0", name: "businesses_delivery_fee_non_negative"
  end
end
