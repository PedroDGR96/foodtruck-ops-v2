require Rails.root.join("lib/tenancy/tenant_rls")

class CreateCashRegisters < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_registers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :status, null: false, default: "open"
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.decimal :opening_amount, null: false, precision: 12, scale: 2, default: 0
      t.decimal :expected_closing_amount, precision: 12, scale: 2
      t.decimal :actual_closing_amount, precision: 12, scale: 2
      t.decimal :drift, precision: 12, scale: 2
      t.boolean :reconciled
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_check_constraint :cash_registers, "opening_amount >= 0", name: "cash_registers_opening_non_negative"
    add_index :cash_registers, %i[business_id status]
    add_index :cash_registers, %i[business_id opened_at]
    add_index :cash_registers, %i[business_id user_id], unique: true, where: "status = 'open'",
      name: "index_cash_registers_one_open_shift"

    Tenancy::TenantRls.install!(self, :cash_registers)
  end
end
