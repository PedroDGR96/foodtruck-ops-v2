require "rails_helper"

RSpec.describe "BusinessScoped tenancy" do
  let!(:first_business) { create(:business) }
  let!(:second_business) { create(:business) }

  def create_audit_log(business)
    Tenancy.with_business(business) { create(:audit_log, business: business) }
  end

  it "isolates Active Record and raw SQL reads to the current business" do
    first_log = create_audit_log(first_business)
    second_log = create_audit_log(second_business)

    Tenancy.with_business(first_business) do
      expect(AuditLog.pluck(:id)).to contain_exactly(first_log.id)
      result = ActiveRecord::Base.connection.select_values("SELECT id FROM audit_logs")
      expect(result).to contain_exactly(first_log.id)
    end

    Tenancy.with_business(second_business) do
      expect(AuditLog.pluck(:id)).to contain_exactly(second_log.id)
      result = ActiveRecord::Base.connection.select_values("SELECT id FROM audit_logs")
      expect(result).to contain_exactly(second_log.id)
    end
  end

  it "fails loudly when a tenant is absent" do
    expect { AuditLog.count }.to raise_error(Tenancy::TenantNotSetError)
    expect { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM audit_logs") }
      .to raise_error(ActiveRecord::StatementInvalid, /app.business_id|invalid input syntax/)
  end

  it "does not reveal rows for a wrong transaction-local tenant" do
    create_audit_log(first_business)

    ActiveRecord::Base.transaction do
      Tenancy.set_local!(second_business.id)
      expect(ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM audit_logs")).to eq(0)
    end
  end

  it "rejects a business supplied from a different tenant" do
    Tenancy.with_business(first_business) do
      log = AuditLog.new(action: "test", resource: "test", business: second_business)

      expect(log).not_to be_valid
      expect(log.errors[:business_id]).to include("must match the current business")
    end
  end
end
