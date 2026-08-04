class RemoveRlsFromUsers < ActiveRecord::Migration[8.1]
  # `users` is the authentication root: sign-in and session deserialization must
  # find a user by email/id *before* a tenant (business) is known, and the RLS
  # policy rejects every query that runs without the `app.business_id` GUC.
  # Tenant-scoping for `users` is therefore enforced at the application layer via
  # the `BusinessScoped` default scope (which raises loudly without a tenant).
  def up
    execute "ALTER TABLE users DISABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE users NO FORCE ROW LEVEL SECURITY"
    execute "DROP TRIGGER users_set_business_id ON users"
    execute "DROP POLICY tenant_isolation ON users"
  end

  def down
    execute "ALTER TABLE users ENABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE users FORCE ROW LEVEL SECURITY"
    execute <<~SQL
      CREATE POLICY tenant_isolation ON users
        FOR ALL
        USING (business_id = current_setting('app.business_id')::uuid)
        WITH CHECK (business_id = current_setting('app.business_id')::uuid);
    SQL
    execute <<~SQL
      CREATE TRIGGER users_set_business_id
        BEFORE INSERT ON users
        FOR EACH ROW EXECUTE FUNCTION assign_business_id_from_guc();
    SQL
  end
end
