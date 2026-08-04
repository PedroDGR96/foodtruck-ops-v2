require Rails.root.join("lib/tenancy/tenant_rls")

class CreateProductAddonGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :product_addon_groups, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :product, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.boolean :multiple, null: false, default: true
      t.integer :min_select, null: false, default: 0
      t.integer :max_select
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :product_addon_groups, %i[product_id position]

    Tenancy::TenantRls.install!(self, :product_addon_groups)
  end
end
