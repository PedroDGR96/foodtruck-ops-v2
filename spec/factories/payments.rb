FactoryBot.define do
  factory :payment do
    order
    add_attribute(:method) { "cash" }
    amount { 10.0 }
    status { "succeeded" }

    to_create do |payment|
      Tenancy.with_business(payment.order.business) do
        payment.business_id = payment.order.business_id
        payment.save!
      end
    end
  end
end
