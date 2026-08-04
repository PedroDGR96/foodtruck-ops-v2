require Rails.root.join("lib/tenancy/tenant_rls")

class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :categories, %i[business_id position]
    add_index :categories, %i[business_id name], unique: true

    Tenancy::TenantRls.install!(self, :categories)
  end
end
