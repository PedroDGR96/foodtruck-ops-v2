# frozen_string_literal: true

require "rails_helper"

# RLS tenant isolation matrix: proves the Postgres policy itself separates
# tenants, not merely the BusinessScoped default_scope. Every positive case
# deliberately bypasses the AR scope (.unscoped or raw SQL) so a hole in the
# app-layer scope fails right here at the DB boundary.
#
# The policy is tenant_isolation (FOR ALL) with
#   USING (business_id = current_setting('app.business_id')::uuid)
#   WITH CHECK (business_id = current_setting('app.business_id')::uuid)
# and FORCE ROW LEVEL SECURITY, so the table owner cannot bypass it either.
RSpec.describe "RLS tenant isolation matrix", type: :model do
  def connection = ActiveRecord::Base.connection

  let(:alpha) { create(:business) }
  let(:beta) { create(:business) }

  before do
    @alpha_order = Tenancy.with_business(alpha) { create(:order, business: alpha) }
    @beta_order = Tenancy.with_business(beta) { create(:order, business: beta) }
  end

  it "sees only its own rows even when the AR default scope is bypassed" do
    ids = Tenancy.with_business(alpha) { Order.unscoped.pluck(:id) }
    expect(ids).to include(@alpha_order.id)
    expect(ids).not_to include(@beta_order.id)
  end

  it "returns no rows for a raw cross-tenant SELECT" do
    rows = Tenancy.with_business(alpha) do
      connection.select_values("SELECT id FROM orders WHERE id = '#{@beta_order.id}'")
    end
    expect(rows).to be_empty
  end

  it "turns a cross-tenant UPDATE into a no-op" do
    updated = Tenancy.with_business(alpha) do
      connection.update("UPDATE orders SET status = 'paid' WHERE id = '#{@beta_order.id}'")
    end
    expect(updated).to eq(0)
    expect(Tenancy.with_business(beta) { @beta_order.reload.status }).to eq("draft")
  end

  it "turns a cross-tenant DELETE into a no-op" do
    deleted = Tenancy.with_business(alpha) do
      connection.delete("DELETE FROM orders WHERE id = '#{@beta_order.id}'")
    end
    expect(deleted).to eq(0)
    expect(Tenancy.with_business(beta) { Order.find(@beta_order.id) }).to be_present
  end

  it "never persists a row pinned to another tenant (trigger rewrites business_id)" do
    Tenancy.with_business(alpha) do
      connection.execute(<<~SQL)
        INSERT INTO orders (business_id, number, status, kitchen_status, payment_status, created_at, updated_at)
        VALUES ('#{beta.id}', 42424242, 'draft', 'pending', 'pending', now(), now())
      SQL
    end
    row = Tenancy.with_business(alpha) do
      connection.select_one("SELECT business_id FROM orders WHERE number = 42424242")
    end
    expect(row["business_id"]).to eq(alpha.id)
  end

  it "raises the missing-GUC error when a tenant table is read outside a tenant block" do
    expect { Order.unscoped.first }
      .to raise_error(ActiveRecord::StatementInvalid, /invalid input syntax for type uuid: ""/)
  end
end
