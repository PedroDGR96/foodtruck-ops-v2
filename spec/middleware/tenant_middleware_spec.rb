require "rails_helper"

RSpec.describe TenantMiddleware do
  it "uses SET LOCAL and clears Current after the request" do
    business = create(:business)
    Tenancy.with_business(business) { create(:user, business: business) }
    app = lambda do |_env|
      [ 200, {}, [ User.count.to_s ] ]
    end

    response = Current.set(business: business) { described_class.new(app).call({}) }

    expect(response.last).to eq([ "1" ])
    expect(Current.business).to be_nil
    setting = ActiveRecord::Base.connection.select_value("SELECT current_setting('app.business_id', true)")

    expect(setting).not_to eq(business.id)
    expect { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM users") }
      .to raise_error(ActiveRecord::StatementInvalid, /app.business_id|invalid input syntax/)
  end
end
