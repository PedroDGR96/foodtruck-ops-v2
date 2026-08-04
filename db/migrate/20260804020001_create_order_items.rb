require Rails.root.join("lib/tenancy/tenant_rls")

class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :order, null: false, type: :uuid, foreign_key: true
      t.references :product, null: true, type: :uuid, foreign_key: true
      t.references :product_variant, null: true, type: :uuid, foreign_key: true
      t.string :product_name, null: false
      t.string :variant_name
      t.decimal :unit_price, null: false, precision: 12, scale: 2, default: 0
      t.integer :quantity, null: false, default: 1
      t.decimal :line_total, null: false, precision: 12, scale: 2, default: 0
      t.timestamps
    end

    add_check_constraint :order_items, "unit_price >= 0", name: "order_items_unit_price_non_negative"
    add_check_constraint :order_items, "line_total >= 0", name: "order_items_line_total_non_negative"
    add_check_constraint :order_items, "quantity > 0", name: "order_items_quantity_positive"
    add_index :order_items, %i[order_id product_id]

    Tenancy::TenantRls.install!(self, :order_items)
  end
end
