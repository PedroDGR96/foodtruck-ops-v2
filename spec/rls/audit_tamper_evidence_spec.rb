# frozen_string_literal: true

require "rails_helper"

# OWASP Database Security Cheat Sheet (granular permissions): an audit trail
# must be tamper-evident. The runtime role may append and read audit rows but
# can never modify or erase them - enforced at the SQL privilege level so no
# application bug or injected query can rewrite history. db-apply points:
# bin/db-prepare revokes UPDATE/DELETE after the blanket table grant.
RSpec.describe "Audit log tamper evidence", type: :model do
  def connection = ActiveRecord::Base.connection

  def privileged?(privilege)
    # Privilege names are test-local constants, not user input.
    connection.select_value(
      "SELECT has_table_privilege('app', 'audit_logs', '#{privilege}')"
    )
  end

  it "lets the runtime role append and read audit rows" do
    expect(privileged?("INSERT")).to be(true)
    expect(privileged?("SELECT")).to be(true)
  end

  it "denies the runtime role any modification of audit rows" do
    expect(privileged?("UPDATE")).to be(false)
    expect(privileged?("DELETE")).to be(false)
  end

  # Each probe lets the privilege error cross the with_business boundary so
  # the framework rolls back to its savepoint - rescuing inside the block
  # would leave the transaction aborted and mask the real error.
  it "rejects updates and deletes at the SQL level even if code tries" do
    business = create(:business)
    entry = Tenancy.with_business(business) do
      AuditLog.record!(action: "tamper_probe", resource: "spec", actor: nil)
      AuditLog.order(:created_at).last
    end

    update_error = grab_violation(business) { entry.update!(action: "rewritten") }
    delete_error = grab_violation(business) { entry.destroy! }

    expect(update_error).to match(/permission denied/)
    expect(delete_error).to match(/permission denied/)
  end

  def grab_violation(business)
    messages = []
    begin
      Tenancy.with_business(business) { yield }
    rescue ActiveRecord::StatementInvalid => e
      # The pg adapter surfaces the retry's InFailedSqlTransaction on top;
      # the root cause carries the actual privilege denial.
      cur = e
      while cur.respond_to?(:message)
        messages << cur.message
        cur = cur.cause
      end
    end
    messages.join(" ")
  end

  it "keeps legitimate audit writes working through record!" do
    business = create(:business)
    Tenancy.with_business(business) do
      expect do
        AuditLog.record!(action: "legit_write", resource: "spec", actor: nil)
      end.to change(AuditLog, :count).by(1)
    end
  end
end
