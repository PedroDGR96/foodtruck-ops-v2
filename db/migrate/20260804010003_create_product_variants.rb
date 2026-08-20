require Rails.root.join("lib/tenancy/tenant_rls")

class CreateProductVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :product_variants, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :product, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.decimal :price, precision: 12, scale: 2
      t.integer :stock
      t.boolean :active, null: false, default: true
      t.datetime :discarded_at
      t.timestamps
    end

    add_check_constraint :product_variants, "price IS NULL OR price >= 0", name: "product_variants_price_non_negative"
    add_index :product_variants, %i[product_id name], unique: true

    Tenancy::TenantRls.install!(self, :product_variants)
  end
end
