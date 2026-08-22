# frozen_string_literal: true

require "rails_helper"

# CIS PostgreSQL Benchmark control: row-level security must be enabled AND
# forced on every multi-tenant table. FORCE matters because the table owner
# would otherwise bypass policies entirely.
#
# This spec auto-discovers any table carrying a business_id column, so a new
# BusinessScoped model whose migration forgets ENABLE/FORCE ROW LEVEL SECURITY
# fails right here instead of shipping an isolation hole.
#
# Documented exceptions live in EXCEPTIONS with their justification; adding a
# key there without a written reason is a review blocker.
RSpec.describe "RLS enablement and enforcement", type: :model do
  EXCEPTIONS = {
    "users" =>
      "login resolves the user by email before any tenant context exists",
    "tokens" =>
      "token authentication resolves the token before any tenant context exists"
  }.freeze

  def connection = ActiveRecord::Base.connection

  def tenant_tables
    connection.select_values(<<~SQL)
      SELECT DISTINCT c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN information_schema.columns col
        ON col.table_schema = n.nspname AND col.table_name = c.relname
      WHERE n.nspname = 'public'
        AND c.relkind = 'r'
        AND col.column_name = 'business_id'
      ORDER BY 1
    SQL
  end

  it "has no undocumented business-scoped table" do
    expect(tenant_tables - EXCEPTIONS.keys).to be_present,
                                                "no tenant tables found - discovery query broken?"
  end

  it "enables and forces row level security on every tenant table" do
    unguarded = tenant_tables - EXCEPTIONS.keys - connection.select_values(<<~SQL)
      SELECT relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND relkind = 'r'
        AND relrowsecurity = true
        AND relforcerowsecurity = true
    SQL

    expect(unguarded).to be_empty,
                         "tenant tables without ENABLE+FORCE RLS:\n  #{unguarded.join("\n  ")}"
  end

  it "declares at least one policy on every protected tenant table" do
    unprotected = (tenant_tables - EXCEPTIONS.keys) - connection.select_values(<<~SQL)
      SELECT DISTINCT tablename
      FROM pg_policies
      WHERE schemaname = 'public'
    SQL

    expect(unprotected).to be_empty,
                           "protected tables with no policy:\n  #{unprotected.join("\n  ")}"
  end

  it "keeps every exception justified and still business-scoped" do
    unknown = EXCEPTIONS.keys - tenant_tables
    expect(unknown).to be_empty,
                       "exceptions no longer have business_id (remove them): #{unknown.join(', ')}"
  end
end
