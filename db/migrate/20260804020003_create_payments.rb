require Rails.root.join("lib/tenancy/tenant_rls")

class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :order, null: false, type: :uuid, foreign_key: true
      t.string :method, null: false
      t.decimal :amount, null: false, precision: 12, scale: 2, default: 0
      t.string :status, null: false, default: "succeeded"
      t.string :gateway_reference
      t.timestamps
    end

    add_check_constraint :payments, "amount >= 0", name: "payments_amount_non_negative"

    Tenancy::TenantRls.install!(self, :payments)
  end
end
