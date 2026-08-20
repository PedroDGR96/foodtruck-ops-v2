require Rails.root.join("lib/tenancy/tenant_rls")

class CreateOrderItemAddons < ActiveRecord::Migration[8.1]
  def change
    create_table :order_item_addons, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :order_item, null: false, type: :uuid, foreign_key: true
      t.references :product_addon, null: true, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.decimal :price, null: false, precision: 12, scale: 2, default: 0
      t.timestamps
    end

    add_check_constraint :order_item_addons, "price >= 0", name: "order_item_addons_price_non_negative"

    Tenancy::TenantRls.install!(self, :order_item_addons)
  end
end
