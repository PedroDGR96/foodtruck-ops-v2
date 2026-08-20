FactoryBot.define do
  factory :product_addon do
    association :business
    product_addon_group { association(:product_addon_group, business: business) }
    sequence(:name) { |number| "Addon #{number}" }
    price { 0 }
    active { true }

    to_create do |addon|
      Tenancy.with_business(addon.business) { addon.save! }
    end
  end
end
