require Rails.root.join("lib/tenancy/tenant_rls")

class FixLgpdComplianceRls < ActiveRecord::Migration[8.1]
  LGPD_TABLES = %i[consent_records data_subject_requests privacy_incidents].freeze

  def up
    LGPD_TABLES.each do |table|
      change_column_default table, :id, -> { "gen_random_uuid()" }
      Tenancy::TenantRls.install!(self, table)
    end
  end

  def down
    LGPD_TABLES.each do |table|
      connection.execute(<<~SQL)
        DROP TRIGGER IF EXISTS #{table}_set_business_id ON #{table};
        DROP POLICY IF EXISTS tenant_isolation ON #{table};
        ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table} NO FORCE ROW LEVEL SECURITY;
      SQL
      change_column_default table, :id, nil
    end
  end
end
