FactoryBot.define do
  factory :audit_log do
    association :business
    action { "sign_in" }
    resource { "session" }
    metadata { {} }

    to_create do |audit_log|
      Tenancy.with_business(audit_log.business) { audit_log.save! }
    end
  end
end
