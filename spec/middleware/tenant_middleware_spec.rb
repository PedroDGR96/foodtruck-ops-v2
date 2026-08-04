require "rails_helper"

RSpec.describe TenantMiddleware do
  def build_app
    ->(_env) { [ 200, {}, [ AuditLog.count.to_s ] ] }
  end

  def assert_tenant_reset
    expect(Current.business).to be_nil
    setting = ActiveRecord::Base.connection.select_value("SELECT current_setting('app.business_id', true)")
    expect(setting).to be_blank
  end

  it "uses SET LOCAL and clears Current after the request when Current.business is set" do
    business = create(:business)
    Tenancy.with_business(business) { create(:audit_log, business: business) }

    response = Current.set(business: business) { described_class.new(build_app).call({}) }

    expect(response.last).to eq([ "1" ])
    assert_tenant_reset
  end

  it "resolves the business from the authenticated warden user" do
    business = create(:business)
    user = Tenancy.with_business(business) { create(:user, business: business) }
    Tenancy.with_business(business) { create(:audit_log, business: business) }

    warden = double("warden", user: user)
    response = described_class.new(build_app).call({ "warden" => warden })

    expect(response.last).to eq([ "1" ])
    assert_tenant_reset
  end

  it "passes through without a tenant when nobody is signed in" do
    app = ->(_env) { [ 200, {}, [ "ok" ] ] }

    response = described_class.new(app).call({})

    expect(response.last).to eq([ "ok" ])
    expect(Current.business).to be_nil
  end
end
