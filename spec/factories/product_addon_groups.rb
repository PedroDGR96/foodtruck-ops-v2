FactoryBot.define do
  factory :product_addon_group do
    association :business
    product { association(:product, business: business) }
    sequence(:name) { |number| "Addon group #{number}" }
    multiple { true }
    min_select { 0 }
    max_select { nil }
    position { 0 }
    active { true }

    to_create do |group|
      Tenancy.with_business(group.business) { group.save! }
    end
  end
end
