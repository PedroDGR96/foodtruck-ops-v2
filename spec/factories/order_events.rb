FactoryBot.define do
  factory :order_event do
    order
    event { "confirmed" }
    metadata { { "from" => "draft", "to" => "open" } }

    to_create do |event|
      Tenancy.with_business(event.order.business) { event.save! }
    end
  end
end
