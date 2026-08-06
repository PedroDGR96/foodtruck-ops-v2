require Rails.root.join("lib/tenancy/tenant_rls")

class CreateDeliveryAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :delivery_addresses, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :order, null: false, type: :uuid, foreign_key: true, index: { unique: true }
      t.string :street, null: false
      t.string :number
      t.string :complement
      t.string :neighborhood
      t.string :city, null: false
      t.string :state, null: false
      t.string :zip
      t.string :reference
      t.timestamps
    end

    Tenancy::TenantRls.install!(self, :delivery_addresses)
  end
end
