require Rails.root.join("lib/tenancy/tenant_rls")

class CreateOrderEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :order_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :order, null: false, type: :uuid, foreign_key: true
      t.references :user, null: true, type: :uuid, foreign_key: true
      t.string :event, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :order_events, %i[order_id created_at]

    Tenancy::TenantRls.install!(self, :order_events)
  end
end
