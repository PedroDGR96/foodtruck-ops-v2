require Rails.root.join("lib/tenancy/tenant_rls")

class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :category, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.decimal :price, null: false, precision: 12, scale: 2, default: 0
      t.string :status, null: false, default: "available"
      t.integer :position, null: false, default: 0
      t.datetime :discarded_at
      t.timestamps
    end

    add_check_constraint :products, "price >= 0", name: "products_price_non_negative"
    add_index :products, %i[category_id position]
    add_index :products, %i[business_id name], unique: true

    Tenancy::TenantRls.install!(self, :products)
  end
end
