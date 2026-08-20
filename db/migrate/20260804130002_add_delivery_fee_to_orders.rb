class AddDeliveryFeeToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :delivery_fee, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_check_constraint :orders, "delivery_fee >= 0", name: "orders_delivery_fee_non_negative"
  end
end
