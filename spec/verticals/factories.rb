# frozen_string_literal: true

require "rails_helper"

FactoryBot.define do
  sequence(:business_name) { |n| "Business #{n}" }
  sequence(:user_email) { |n| "user#{n}@example.com" }
  sequence(:cashier_email) { |n| "cashier#{n}@example.com" }
  sequence(:kitchen_email) { |n| "kitchen#{n}@example.com" }
  sequence(:staff_email) { |n| "staff#{n}@example.com" }
  sequence(:customer_email) { |n| "customer#{n}@example.com" }

  trait :with_business do
    business { create(:business, name: next_sequence_value(:business_name)) }
  end

  factory :user, class: "User", aliases: ["user"] do
    email { next_sequence_value(:user_email) }
    password { "password123" }
    password_confirmation { "password123" }
    role { :cashier }

    trait :owner do
      role { :owner }
    end

    trait :cashier do
      role { :cashier }
    end

    trait :kitchen do
      role { :kitchen }
    end

    trait :staff do
      role { :staff }
    end

    transient do
      business_id { nil }
    end

    after(:build) do |user|
      user.business = user.business_id ? Business.find(user.business_id) : nil
    end
  end

  factory :business, class: "Business", aliases: ["business"] do
    name { next_sequence_value(:business_name) }
    slug { name.parameterize }

    transient do
      location_attributes { { address: "123 Main St" } }
    end

    after(:build) do |business|
      business.location = Location.new(business.location_attributes) if business.location_attributes.present?
    end
  end

  factory :order, class: "Order", aliases: ["order"] do
    status { :draft }
    subtotal { 0.0 }
    total { 0.0 }
    tax_amount { 0.0 }
    discount_amount { 0.0 }
    payment_status { :unpaid }

    transient do
      business_id { nil }
    end

    after(:build) do |order|
      order.business = order.business_id ? Business.find(order.business_id) : nil
    end
  end

  factory :order_item, class: "OrderItem", aliases: ["order_item"] do
    quantity { 1 }
    unit_price { 0.0 }
    product_name { "Product" }

    transient do
      order { nil }
    end

    after(:build) do |item|
      item.order = item.order ? Order.find(item.order.id) : nil
    end
  end

  factory :product, class: "Product", aliases: ["product"] do
    name { "Test Product" }
    description { "A test product" }
    price { 10.0 }
    cost_price { 5.0 }
    sku { "SKU-TEST-001" }

    trait :with_variant do
      variants { [create(:product_variant, product: nil)] }
    end

    transient do
      business_id { nil }
    end

    after(:build) do |product|
      product.business = product.business_id ? Business.find(product.business_id) : nil
    end
  end

  factory :product_variant, class: "ProductVariant", aliases: ["variant"] do
    name { "Standard" }
    price { 10.0 }
    cost_price { 5.0 }

    transient do
      product { nil }
    end

    after(:build) do |variant|
      variant.product = variant.product ? Product.find(variant.product.id) : nil
    end
  end

  factory :cart_item, class: "CartItem", aliases: ["cart_item"] do
    quantity { 1 }
    unit_price { 0.0 }
    product_name { "Product" }
    variant_id { nil }

    transient do
      cart { nil }
    end

    after(:build) do |item|
      item.cart = item.cart ? Cart.find(item.cart.id) : nil
    end
  end

  factory :cart, class: "Cart", aliases: ["cart"] do
    subtotal { 0.0 }
    total { 0.0 }
    tax_amount { 0.0 }
    discount_amount { 0.0 }

    transient do
      business_id { nil }
    end

    after(:build) do |cart|
      cart.business = cart.business_id ? Business.find(cart.business_id) : nil
    end
  end

  factory :payment, class: "Payment", aliases: ["payment"] do
    amount { 0.0 }
    status { :pending }
    payment_method { :card }
    reference_number { SecureRandom.uuid }

    transient do
      order { nil }
    end

    after(:build) do |payment|
      payment.order = payment.order ? Order.find(payment.order.id) : nil
    end
  end

  factory :cash_register, class: "CashRegister", aliases: ["register"] do
    name { "Main Register" }
    opening_amount { 100.0 }
    closing_amount { 100.0 }
    cash_sales { 0.0 }
    card_sales { 0.0 }
    pending_payments { [] }

    trait :open do
      status { :open }
    end

    trait :closed do
      status { :closed }
    end

    transient do
      business_id { nil }
    end

    after(:build) do |register|
      register.business = register.business_id ? Business.find(register.business_id) : nil
    end
  end

  factory :cash_register_ledger, class: "CashRegisterLedger", aliases: ["ledger"] do
    description { "Test entry" }
    amount { 0.0 }
    type { :sale }
    reference_number { SecureRandom.uuid }

    transient do
      register { nil }
    end

    after(:build) do |entry|
      entry.register = entry.register ? CashRegister.find(entry.register.id) : nil
    end
  end

  factory :employee, class: "Employee", aliases: ["employee"] do
    name { "Test Employee" }
    email { next_sequence_value(:staff_email) }
    role { :kitchen }
    phone { "+5511999999999" }

    transient do
      business_id { nil }
    end

    after(:build) do |employee|
      employee.business = employee.business_id ? Business.find(employee.business_id) : nil
    end
  end

  factory :menu, class: "Menu", aliases: ["menu"] do
    name { "Main Menu" }
    description { "The main menu for this business" }

    transient do
      business_id { nil }
    end

    after(:build) do |menu|
      menu.business = menu.business_id ? Business.find(menu.business_id) : nil
    end
  end

  factory :category, class: "Category", aliases: ["category"] do
    name { "Drinks" }
    description { "All drink items" }

    transient do
      business_id { nil }
    end

    after(:build) do |category|
      category.business = category.business_id ? Business.find(category.business_id) : nil
    end
  end

  factory :order_status, class: "OrderStatus", aliases: ["status"] do
    name { "Draft" }
    description { "The order is being prepared" }
    code { "draft" }

    transient do
      business_id { nil }
    end

    after(:build) do |status|
      status.business = status.business_id ? Business.find(status.business_id) : nil
    end
  end

  factory :payment_method, class: "PaymentMethod", aliases: ["payment_method"] do
    name { "Credit Card" }
    description { "Credit card payments" }
    code { "card" }

    transient do
      business_id { nil }
    end

    after(:build) do |method|
      method.business = method.business_id ? Business.find(method.business_id) : nil
    end
  end

  factory :order_status_transition, class: "OrderStatusTransition", aliases: ["transition"] do
    from_status { nil }
    to_status { nil }
    description { "Transitioned the order" }
    actor { nil }

    transient do
      business_id { nil }
    end

    after(:build) do |transition|
      transition.business = transition.business_id ? Business.find(transition.business_id) : nil
      transition.from_status = transition.from_status ? OrderStatus.find(transition.from_status.id) : nil
      transition.to_status = transition.to_status ? OrderStatus.find(transition.to_status.id) : nil
    end
  end

  factory :order_workflow, class: "OrderWorkflow", aliases: ["workflow"] do
    name { "Standard Workflow" }
    description { "The standard order workflow" }
    steps { [] }

    transient do
      business_id { nil }
    end

    after(:build) do |workflow|
      workflow.business = workflow.business_id ? Business.find(workflow.business_id) : nil
    end
  end

  factory :order_workflow_step, class: "OrderWorkflowStep", aliases: ["step"] do
    name { "Draft" }
    description { "The order is being prepared" }
    code { "draft" }
    display_order { 1 }
    previous_status { nil }
    next_status { nil }

    transient do
      business_id { nil }
    end

    after(:build) do |step|
      step.business = step.business_id ? Business.find(step.business_id) : nil
    end
  end
end
