FactoryBot.define do
  factory :integration_setting do
    association :business
    provider_key { "payment_gateway" }
    credentials { { api_key: "test_key", endpoint: "https://example.test" } }
    enabled { true }

    to_create do |setting|
      Tenancy.with_business(setting.business) { setting.save! }
    end
  end
end
