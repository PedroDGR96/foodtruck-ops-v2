FactoryBot.define do
  factory :product do
    association :business
    category { association(:category, business: business) }
    sequence(:name) { |number| "Product #{number}" }
    description { "Uma descrição" }
    price { 10.0 }
    status { "available" }
    position { 0 }

    to_create do |product|
      Tenancy.with_business(product.business) { product.save! }
    end

    trait :unavailable do
      status { "unavailable" }
    end
  end
end
