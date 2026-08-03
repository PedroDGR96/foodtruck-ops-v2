module Tenancy::TenantRls
  POLICY_NAME = "tenant_isolation".freeze
  TRIGGER_FUNCTION = "assign_business_id_from_guc".freeze

  def self.install!(migration, table_name)
    table = migration.connection.quote_table_name(table_name)
    trigger = migration.connection.quote_column_name("#{table_name}_set_business_id")
    policy = migration.connection.quote_column_name(POLICY_NAME)

    migration.execute <<~SQL
      CREATE OR REPLACE FUNCTION #{TRIGGER_FUNCTION}()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        NEW.business_id := current_setting('app.business_id')::uuid;
        RETURN NEW;
      END;
      $$;

      ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
      ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;
      CREATE POLICY #{policy} ON #{table}
        FOR ALL
        USING (business_id = current_setting('app.business_id')::uuid)
        WITH CHECK (business_id = current_setting('app.business_id')::uuid);
      CREATE TRIGGER #{trigger}
        BEFORE INSERT ON #{table}
        FOR EACH ROW EXECUTE FUNCTION #{TRIGGER_FUNCTION}();
      GRANT SELECT, INSERT, UPDATE, DELETE ON #{table} TO app;
    SQL
  end
end
