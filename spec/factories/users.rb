FactoryBot.define do
  factory :user do
    association :business
    sequence(:name) { |number| "User #{number}" }
    sequence(:email) { |number| "user#{number}@example.test" }
    role { "owner" }
    password { "password123" }
    password_confirmation { "password123" }

    to_create do |user|
      Tenancy.with_business(user.business) { user.save! }
    end

    trait :owner do
      role { "owner" }
    end

    trait :cashier do
      role { "cashier" }
    end

    trait :kitchen do
      role { "kitchen" }
    end
  end
end
