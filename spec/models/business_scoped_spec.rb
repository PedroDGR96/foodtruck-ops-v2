require "rails_helper"

RSpec.describe User do
  let!(:first_business) { create(:business) }
  let!(:second_business) { create(:business) }

  it "isolates Active Record and raw SQL reads to the current business" do
    first_user = Tenancy.with_business(first_business) { create(:user, business: first_business) }
    second_user = Tenancy.with_business(second_business) { create(:user, business: second_business) }

    Tenancy.with_business(first_business) do
      expect(User.pluck(:id)).to contain_exactly(first_user.id)
      result = ActiveRecord::Base.connection.select_values("SELECT id FROM users")
      expect(result).to contain_exactly(first_user.id)
    end

    Tenancy.with_business(second_business) do
      expect(User.pluck(:id)).to contain_exactly(second_user.id)
      result = ActiveRecord::Base.connection.select_values("SELECT id FROM users")
      expect(result).to contain_exactly(second_user.id)
    end
  end

  it "fails loudly when a tenant is absent" do
    expect { User.count }.to raise_error(Tenancy::TenantNotSetError)
    expect { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM users") }
      .to raise_error(ActiveRecord::StatementInvalid, /app.business_id|invalid input syntax/)
  end

  it "does not reveal rows for a wrong transaction-local tenant" do
    Tenancy.with_business(first_business) { create(:user, business: first_business) }

    ActiveRecord::Base.transaction do
      Tenancy.set_local!(second_business.id)
      expect(ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM users")).to eq(0)
    end
  end

  it "rejects a business supplied from a different tenant" do
    Tenancy.with_business(first_business) do
      user = User.new(name: "Cross tenant", email: "cross@example.test", role: "owner", business: second_business)

      expect(user).not_to be_valid
      expect(user.errors[:business_id]).to include("must match the current business")
    end
  end
end
