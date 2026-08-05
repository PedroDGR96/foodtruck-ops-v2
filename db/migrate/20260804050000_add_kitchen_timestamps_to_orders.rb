class AddKitchenTimestampsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :started_at, :datetime, null: true
    add_column :orders, :finished_at, :datetime, null: true
  end
end
