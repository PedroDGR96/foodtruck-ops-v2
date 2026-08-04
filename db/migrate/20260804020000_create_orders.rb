require Rails.root.join("lib/tenancy/tenant_rls")

class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :user, null: true, type: :uuid, foreign_key: true
      t.references :customer, null: true, type: :uuid
      t.string :order_type, null: false, default: "local"
      t.string :status, null: false, default: "draft"
      t.string :kitchen_status, null: false, default: "pending"
      t.string :payment_status, null: false, default: "pending"
      t.decimal :subtotal, null: false, precision: 12, scale: 2, default: 0
      t.decimal :tax, null: false, precision: 12, scale: 2, default: 0
      t.decimal :total, null: false, precision: 12, scale: 2, default: 0
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_check_constraint :orders, "subtotal >= 0", name: "orders_subtotal_non_negative"
    add_check_constraint :orders, "tax >= 0", name: "orders_tax_non_negative"
    add_check_constraint :orders, "total >= 0", name: "orders_total_non_negative"
    add_index :orders, %i[business_id status]
    add_index :orders, %i[business_id created_at]
    add_index :orders, %i[business_id user_id]

    Tenancy::TenantRls.install!(self, :orders)
  end
end
