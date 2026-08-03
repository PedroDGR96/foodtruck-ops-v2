require "rails_helper"

RSpec.describe Tenancy::SidekiqServerMiddleware do
  it "fails loudly when a job without a tenant touches tenant data" do
    expect do
      described_class.new.call(nil, {}, "default") { User.count }
    end.to raise_error(Tenancy::TenantNotSetError)
  end

  it "sets the tenant for a declared job" do
    business = create(:business)
    user = Tenancy.with_business(business) { create(:user, business: business) }

    count = described_class.new.call(nil, { "business_id" => business.id }, "default") { User.where(id: user.id).count }

    expect(count).to eq(1)
  end

  it "adds the current business to newly enqueued Sidekiq work" do
    business = create(:business)
    job = {}

    result = Current.set(business: business) do
      Tenancy::SidekiqClientMiddleware.new.call(nil, job, "default", nil) { :enqueued }
    end

    expect(result).to eq(:enqueued)
    expect(job).to include("business_id" => business.id)
  end
end
