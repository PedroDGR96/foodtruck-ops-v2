FactoryBot.define do
  factory :customer do
    association :business
    sequence(:name) { |number| "Customer #{number}" }
    phone { "11999999999" }
    whatsapp { nil }
    birthday { nil }
    notes { nil }

    to_create do |customer|
      Tenancy.with_business(customer.business) { customer.save! }
    end
  end
end
