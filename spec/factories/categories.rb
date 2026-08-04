FactoryBot.define do
  factory :category do
    association :business
    sequence(:name) { |number| "Category #{number}" }
    position { 0 }
    active { true }

    to_create do |category|
      Tenancy.with_business(category.business) { category.save! }
    end
  end
end
