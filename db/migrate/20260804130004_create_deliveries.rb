require Rails.root.join("lib/tenancy/tenant_rls")

class CreateDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :deliveries, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :order, null: false, type: :uuid, foreign_key: true
      t.string :courier_name
      t.string :status, null: false, default: "pending"
      t.timestamps
    end

    add_check_constraint :deliveries, "status IN ('pending', 'out_for_delivery', 'delivered')", name: "deliveries_status_is_valid"
    add_index :deliveries, %i[business_id status]

    Tenancy::TenantRls.install!(self, :deliveries)
  end
end
