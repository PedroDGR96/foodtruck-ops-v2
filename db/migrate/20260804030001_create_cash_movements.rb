require Rails.root.join("lib/tenancy/tenant_rls")

class CreateCashMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_movements, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :cash_register, null: false, type: :uuid, foreign_key: true
      t.references :order, null: true, type: :uuid, foreign_key: true
      t.references :payment, null: true, type: :uuid, foreign_key: true
      t.references :created_by, null: true, type: :uuid, foreign_key: { to_table: :users }
      t.string :movement_type, null: false
      t.string :category, null: false
      t.decimal :amount, null: false, precision: 12, scale: 2, default: 0
      t.string :reason, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_check_constraint :cash_movements, "amount >= 0", name: "cash_movements_amount_non_negative"
    add_check_constraint :cash_movements, "movement_type IN ('income', 'expense')",
      name: "cash_movements_type_is_valid"
    add_index :cash_movements, %i[cash_register_id created_at]
    add_index :cash_movements, %i[business_id created_at]
    add_index :cash_movements, %i[business_id order_id]

    Tenancy::TenantRls.install!(self, :cash_movements)
  end
end
