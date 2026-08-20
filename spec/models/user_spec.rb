require "rails_helper"

RSpec.describe User do
  let(:business) { create(:business) }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "roles" do
    it "exposes role predicates" do
      owner = within_tenant { build(:user, :owner) }
      cashier = within_tenant { build(:user, :cashier) }

      expect(owner).to be_owner
      expect(cashier).to be_cashier
      expect(owner).not_to be_cashier
    end
  end

  describe "tenant scoping" do
    it "requires a current business for scoped work" do
      expect { User.new }.to raise_error(Tenancy::TenantNotSetError)
      expect { User.count }.to raise_error(Tenancy::TenantNotSetError)
    end

    it "supports unscoped lookups outside a tenant block" do
      user = within_tenant { create(:user, business: business) }

      expect(User.unscoped.find(user.id)).to eq(user)
    end

    it "enforces global email uniqueness across businesses" do
      within_tenant { create(:user, email: "shared@example.test", business: business) }
      create(:business)

      within_tenant do
        duplicate = User.new(email: "SHARED@example.test", name: "Dup", role: "cashier",
                             password: "password123", password_confirmation: "password123")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:email]).to be_present
      end
    end
  end

  describe "authentication" do
    it "finds users by auth conditions without a tenant" do
      user = within_tenant { create(:user, email: "auth@example.test", business: business) }

      found = User.find_first_by_auth_conditions({ email: "auth@example.test" })

      expect(found).to eq(user)
    end

    it "validates passwords against the global email" do
      user = within_tenant { create(:user, email: "auth@example.test", business: business) }

      expect(user.valid_password?("password123")).to be(true)
      expect(user.valid_password?("nope")).to be(false)
    end

    it "is inactive when the active flag is off" do
      user = within_tenant { create(:user, active: false, business: business) }

      expect(user).not_to be_active_for_authentication
      expect(user.inactive_message).to eq(:inactive)
    end
  end

  describe "locking" do
    it "reports the configured lock threshold" do
      user = within_tenant { build(:user, business: business) }

      expect(described_class.maximum_attempts).to eq(5)
      expect(user.timeout_in).to eq(2.hours)
    end

    it "audits lock and unlock events" do
      user = within_tenant { create(:user, business: business) }

      within_tenant do
        user.lock_access!
        expect(AuditLog.where(action: "user_locked", resource_id: user.id.to_s).count).to eq(1)

        user.unlock_access!
        expect(AuditLog.where(action: "user_unlocked", resource_id: user.id.to_s).count).to eq(1)
      end
    end
  end
end
