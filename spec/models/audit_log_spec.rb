require "rails_helper"

RSpec.describe AuditLog do
  let(:business) { create(:business) }

  describe "validation" do
    it "requires an action and a resource" do
      Tenancy.with_business(business) do
        log = AuditLog.new(business: business)

        expect(log).not_to be_valid
        expect(log.errors[:action]).to be_present
        expect(log.errors[:resource]).to be_present
      end
    end
  end

  describe ".record!" do
    it "persists an audit entry with an actor" do
      user = Tenancy.with_business(business) { create(:user, business: business) }

      Tenancy.with_business(business) do
        log = AuditLog.record!(
          action: "custom_action",
          resource: "widget",
          resource_id: 42,
          actor: user,
          metadata: { reason: "test" }
        )

        expect(log.action).to eq("custom_action")
        expect(log.resource).to eq("widget")
        expect(log.resource_id).to eq("42")
        expect(log.actor_id).to eq(user.id)
        expect(log.metadata).to eq({ "reason" => "test" })
        expect(log.business_id).to eq(business.id)
      end
    end

    it "falls back to an explicit actor_id" do
      user = Tenancy.with_business(business) { create(:user, business: business) }

      log = Tenancy.with_business(business) do
        AuditLog.record!(action: "test", resource: "user", actor_id: user.id)
      end

      expect(log.actor_id).to eq(user.id)
    end
  end

  it "requires a tenant" do
    expect { AuditLog.record!(action: "test", resource: "widget") }
      .to raise_error(Tenancy::TenantNotSetError)
  end
end
