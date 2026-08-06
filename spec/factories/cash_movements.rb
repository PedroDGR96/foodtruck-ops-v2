FactoryBot.define do
  factory :cash_movement do
    association :cash_register
    movement_type { "income" }
    category { "cash_drop" }
    amount { 10.0 }
    reason { "Test movement" }

    to_create do |movement|
      Tenancy.with_business(movement.cash_register.business) { movement.save! }
    end
  end
end
