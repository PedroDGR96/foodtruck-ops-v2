require Rails.root.join("lib/tenancy/tenant_rls")

class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.string :action, null: false
      t.string :resource, null: false
      t.string :resource_id
      t.uuid :actor_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :audit_logs, :action
    add_index :audit_logs, %i[business_id created_at]

    Tenancy::TenantRls.install!(self, :audit_logs)
  end
end
