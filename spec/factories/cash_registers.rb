FactoryBot.define do
  factory :cash_register do
    association :business
    user { association(:user, :cashier, business: business) }
    opening_amount { 100.0 }
    opened_at { Time.current }

    to_create do |register|
      Tenancy.with_business(register.business) { register.save! }
    end

    trait :open do
      status { "open" }
    end

    trait :closed do
      status { "closed" }
      closed_at { Time.current }
      opening_amount { 100.0 }
      actual_closing_amount { 100.0 }
      expected_closing_amount { 100.0 }
      drift { 0.0 }
      reconciled { true }
    end
  end
end
