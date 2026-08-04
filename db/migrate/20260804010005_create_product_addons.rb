require Rails.root.join("lib/tenancy/tenant_rls")

class CreateProductAddons < ActiveRecord::Migration[8.1]
  def change
    create_table :product_addons, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :product_addon_group, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.decimal :price, null: false, precision: 12, scale: 2, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :discarded_at
      t.timestamps
    end

    add_check_constraint :product_addons, "price >= 0", name: "product_addons_price_non_negative"
    add_index :product_addons, %i[product_addon_group_id name], unique: true

    Tenancy::TenantRls.install!(self, :product_addons)
  end
end
