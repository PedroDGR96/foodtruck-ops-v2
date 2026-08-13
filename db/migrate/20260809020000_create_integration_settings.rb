require Rails.root.join("lib/tenancy/tenant_rls")

class CreateIntegrationSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :integration_settings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.string :provider_key, null: false
      t.jsonb :credentials
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :integration_settings, %i[business_id provider_key], unique: true
    Tenancy::TenantRls.install!(self, :integration_settings)
  end
end
