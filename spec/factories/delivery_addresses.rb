FactoryBot.define do
  factory :delivery_address do
    association :business
    association :order
    sequence(:street) { |n| "Rua #{n}" }
    number { "123" }
    neighborhood { "Centro" }
    city { "São Paulo" }
    state { "SP" }

    to_create do |address|
      Tenancy.with_business(address.business) { address.save! }
    end
  end
end
