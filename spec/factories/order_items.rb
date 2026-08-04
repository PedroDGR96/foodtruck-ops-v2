FactoryBot.define do
  factory :order_item do
    order
    product { association(:product, business: order.business) }
    product_name { product.name }
    variant_name { nil }
    quantity { 1 }
    unit_price { product.price }

    to_create do |item|
      Tenancy.with_business(item.order.business) do
        item.business_id = item.order.business_id
        item.save!
      end
    end
  end
end
