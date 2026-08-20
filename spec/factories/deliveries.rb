FactoryBot.define do
  factory :delivery do
    association :business
    association :order
    status { "pending" }
    courier_name { nil }

    to_create do |delivery|
      Tenancy.with_business(delivery.business) { delivery.save! }
    end
  end
end
