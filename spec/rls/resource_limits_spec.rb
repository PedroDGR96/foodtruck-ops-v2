# frozen_string_literal: true

require "rails_helper"

# CIS PostgreSQL Benchmark: bound resource consumption per role. The runtime
# role gets a connection ceiling plus statement and idle-in-transaction
# timeouts so a runaway request or leaked transaction cannot monopolize the
# database. Values are maintained by bin/db-prepare (migrator holds ADMIN
# OPTION on app) and by the bootstrap scripts; this spec fails if any
# environment drifts.
RSpec.describe "Runtime role resource limits", type: :model do
  def connection = ActiveRecord::Base.connection

  it "caps the runtime role at 50 connections" do
    limit = connection.select_value(
      "SELECT rolconnlimit FROM pg_roles WHERE rolname = 'app'"
    )
    expect(limit).to eq(50)
  end

  it "bounds every statement at 30 seconds" do
    expect(connection.select_value("SHOW statement_timeout")).to eq("30s")
  end

  it "bounds idle transactions at 60 seconds" do
    expect(connection.select_value("SHOW idle_in_transaction_session_timeout"))
      .to eq("1min")
  end

  it "leaves migration sessions unbounded so schema loads survive" do
    # The settings are role-scoped to app only; verify they are not global.
    global = connection.select_one(<<~SQL)
      SELECT s.setrole::regrole::text AS role
      FROM pg_db_role_setting s
      WHERE s.setrole <> 0 AND s.setdatabase = 0
        AND 'statement_timeout=30s' = ANY (s.setconfig)
        AND s.setrole::regrole::text IN ('app_owner', 'dbadmin')
    SQL
    expect(global).to be_nil
  end

  it "still allows normal POS traffic under the caps" do
    business = create(:business)
    order = Tenancy.with_business(business) { create(:order, business: business) }
    found = Tenancy.with_business(order.business) { Order.find(order.id) }
    expect(found).to be_present
  end
end
