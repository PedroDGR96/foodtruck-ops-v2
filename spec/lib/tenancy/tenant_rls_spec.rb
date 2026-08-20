require "rails_helper"
require Rails.root.join("lib/tenancy/tenant_rls")

RSpec.describe Tenancy::TenantRls do
  it "installs FORCE RLS, an explicit policy, and the insert trigger" do
    connection = Class.new do
      def quote_table_name(name)
        %("#{name}")
      end

      def quote_column_name(name)
        %("#{name}")
      end
    end.new
    migration = Struct.new(:connection, :statements) do
      def execute(statement)
        statements << statement
      end
    end.new(connection, [])

    described_class.install!(migration, :orders)

    statement = migration.statements.fetch(0)
    expect(statement).to include("FORCE ROW LEVEL SECURITY")
    expect(statement).to include("current_setting('app.business_id')::uuid")
    expect(statement).to include("BEFORE INSERT ON \"orders\"")
    expect(statement).not_to include("missing_ok")
  end
end
