FactoryBot.define do
  factory :order_item_addon do
    order_item
    product_addon { association(:product_addon, business: order_item.order.business) }
    name { product_addon.name }
    price { product_addon.price }

    to_create do |addon|
      Tenancy.with_business(addon.order_item.order.business) do
        addon.business_id = addon.order_item.business_id
        addon.save!
      end
    end
  end
end
