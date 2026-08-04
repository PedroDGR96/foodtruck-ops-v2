FactoryBot.define do
  factory :product_variant do
    association :business
    product { association(:product, business: business) }
    sequence(:name) { |number| "Variant #{number}" }
    price { nil }
    stock { nil }
    active { true }

    to_create do |variant|
      Tenancy.with_business(variant.business) { variant.save! }
    end
  end
end
