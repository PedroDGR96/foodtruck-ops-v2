require Rails.root.join("lib/tenancy/tenant_rls")

class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.string :phone
      t.string :whatsapp
      t.date :birthday
      t.text :notes
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :customers, %i[business_id name]
    add_index :customers, %i[business_id phone], unique: true, where: "phone IS NOT NULL AND discarded_at IS NULL"

    add_index :orders, %i[business_id customer_id]
    add_foreign_key :orders, :customers

    Tenancy::TenantRls.install!(self, :customers)
  end
end
