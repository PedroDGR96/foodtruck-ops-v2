# frozen_string_literal: true

require "rails_helper"

# CIS PostgreSQL Benchmark: "Ensure the PostgreSQL superuser account is not
# used for routine database operations" and BYPASSRLS must never coexist with
# runtime credentials.
#
# Posture (see docker/postgres/init-app-role.sql and bin/db-demote-owner):
#   app_owner  idle bootstrap superuser - owns nothing user-visible
#   dbadmin    break-glass superuser
#   migrator   operational role: CREATEDB/CREATEROLE, no superuser, no bypass
#   app        runtime role: fully unprivileged
RSpec.describe "Database role privilege posture", type: :model do
  def connection = ActiveRecord::Base.connection

  def role_attributes
    connection.select_all(<<~SQL).to_a.each_with_object({}) do |row, h|
      SELECT rolname, rolsuper, rolbypassrls, rolcreatedb, rolcreaterole, rolcanlogin
      FROM pg_roles
    SQL
      h[row["rolname"]] = row.symbolize_keys.except(:rolname)
    end
  end

  it "keeps superuser limited to the bootstrap and break-glass roles" do
    expect(role_attributes.select { |_, a| a[:rolsuper] }.keys)
      .to contain_exactly("app_owner", "dbadmin")
  end

  it "grants BYPASSRLS to nobody but the same two roles" do
    expect(role_attributes.select { |_, a| a[:rolbypassrls] && a[:rolcanlogin] }.keys)
      .to contain_exactly("app_owner")
  end

  it "keeps the migration role powerful enough for DDL but never privileged" do
    attrs = role_attributes.fetch("migrator")
    expect(attrs).to match(
      rolsuper: false, rolbypassrls: false, rolcreatedb: true,
      rolcreaterole: true, rolcanlogin: true
    )
  end

  it "keeps the runtime role fully unprivileged" do
    attrs = role_attributes.fetch("app")
    expect(attrs).to match(
      rolsuper: false, rolbypassrls: false, rolcreatedb: false,
      rolcreaterole: false, rolcanlogin: true
    )
  end

  it "owns the application database with the migration role" do
    owner = connection.select_value(<<~SQL)
      SELECT datdba::regrole::text FROM pg_database
      WHERE datname = current_database()
    SQL
    expect(owner).to eq("migrator")
  end

  it "does not grant the runtime role membership in privileged roles" do
    inherited = connection.select_values(<<~SQL)
      SELECT r.rolname
      FROM pg_auth_members m
      JOIN pg_roles member ON member.oid = m.member
      JOIN pg_roles r ON r.oid = m.roleid
      WHERE member.rolname = 'app'
    SQL
    expect(inherited & %w[app_owner dbadmin migrator]).to be_empty
  end

  it "leaves no user objects owned by the bootstrap superuser" do
    stragglers = connection.select_values(<<~SQL)
      SELECT c.relkind::text || ' ' || c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relowner = 'app_owner'::regrole
        AND c.relkind IN ('r', 'v', 'm', 'i', 'S')
    SQL
    expect(stragglers).to be_empty
  end
end
