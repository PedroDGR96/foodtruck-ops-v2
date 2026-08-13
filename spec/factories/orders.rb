FactoryBot.define do
  factory :order do
    association :business
    user { association(:user, business: business) }
    order_type { "local" }
    status { "draft" }
    kitchen_status { "pending" }
    payment_status { "pending" }
    subtotal { 0 }
    tax { 0 }
    total { 0 }
    delivery_fee { 0 }

    to_create do |order|
      Tenancy.with_business(order.business) { order.save! }
    end

    trait :open do
      status { "open" }
    end

    trait :partially_paid do
      status { "partially_paid" }
      payment_status { "partially_paid" }
    end

    trait :paid do
      status { "paid" }
      payment_status { "paid" }
    end

    trait :in_kitchen do
      status { "in_kitchen" }
      kitchen_status { "in_progress" }
      payment_status { "paid" }
    end

    trait :ready do
      status { "ready" }
      kitchen_status { "done" }
      payment_status { "paid" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :refunded do
      status { "refunded" }
      payment_status { "refunded" }
    end

    trait :delivery do
      order_type { "delivery" }
      delivery_fee { 5.0 }
    end
  end
end
