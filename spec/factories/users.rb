FactoryBot.define do
  factory :user do
    association :business
    sequence(:name) { |number| "User #{number}" }
    sequence(:email) { |number| "user#{number}@example.test" }
    role { "owner" }

    to_create do |user|
      Tenancy.with_business(user.business) { user.save! }
    end
  end
end
