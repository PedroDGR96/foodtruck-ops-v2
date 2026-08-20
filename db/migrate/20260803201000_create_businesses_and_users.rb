require Rails.root.join("lib/tenancy/tenant_rls")

class CreateBusinessesAndUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :businesses, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.jsonb :settings, null: false, default: {}
      t.string :currency, null: false, default: "BRL"
      t.string :timezone, null: false, default: "America/Sao_Paulo"
      t.boolean :active, null: false, default: true
      t.datetime :discarded_at
      t.timestamps
    end

    create_table :users, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :role, null: false, default: "owner"
      t.timestamps
    end

    add_index :users, %i[business_id email], unique: true
    add_check_constraint :users, "role IN ('owner', 'cashier', 'kitchen')", name: "users_role_is_valid"

    Tenancy::TenantRls.install!(self, :users)
    execute "GRANT SELECT, INSERT, UPDATE, DELETE ON businesses TO app"
  end
end
