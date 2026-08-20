business = Business.find_by!(name: "FoodTruck Ops")
Tenancy.with_business(business) do
  business.update!(delivery_fee: 8.00) unless business.delivery_fee.present?

  category = Category.find_or_create_by!(name: "Lanches") do |c|
    c.business = business
  end

  items = [
    { name: "X-Burger", price: 28.90 },
    { name: "Batata Frita", price: 15.00 },
    { name: "Suco de Laranja", price: 9.50 }
  ]
  products = items.map do |item|
    Product.find_or_create_by!(business: business, name: item[:name]) do |p|
      p.category = category
      p.price = item[:price]
    end
  end
  x_burger, batata_frita, suco = products

  IntegrationSetting.find_or_create_by!(business: business, provider_key: "payment_gateway") do |s|
    s.credentials = { "mock": true, "endpoint": "https://payments.example.test" }
    s.enabled = true
  end

  cashier = User.find_by!(email: "cashier@foodtruck.local")
  CashRegister.find_or_create_by!(business: business, user: cashier, status: :open) do |r|
    r.opening_amount = 100.00
  end

  # Seed a set of live orders (once) so every screen — POS, checkout, kitchen,
  # orders, home dashboard — has content. Tagged via the partial payment's
  # gateway_reference so re-running the script does not pile up more.
  unless business.payments.exists?(gateway_reference: "demo_partial")
    kitchen_user = User.find_by!(email: "kitchen@foodtruck.local")
    maria = Customer.find_or_create_by!(business: business, phone: "11912345678") do |c|
      c.name = "Maria Silva"
    end

    make_order = lambda do |quantities, customer: nil|
      order = business.orders.build(customer: customer)
      quantities.each do |product, quantity|
        order.order_items.build(product: product, product_name: product.name, unit_price: product.price, quantity: quantity)
      end
      order.save!
      OrderLifecycle.new(order, cashier).confirm!
      order
    end

    # Awaiting payment — checkout shows the recommended step amount.
    make_order.call([ [ x_burger, 2 ], [ batata_frita, 1 ] ])

    # Partially paid — checkout shows history + remaining balance.
    partial = make_order.call([ [ x_burger, 1 ], [ suco, 1 ] ])
    OrderLifecycle.new(partial, cashier).record_payment!(
      partial.payments.build(method: "pix", amount: 20.00, gateway_reference: "demo_partial")
    )

    # In the kitchen — kitchen display shows it in the queue.
    in_kitchen = make_order.call([ [ x_burger, 2 ] ])
    OrderLifecycle.new(in_kitchen, cashier).record_payment!(
      in_kitchen.payments.build(method: "cash", amount: in_kitchen.total)
    )
    OrderLifecycle.new(in_kitchen, kitchen_user).start_cooking!

    # Ready for pickup — shows on the completed rail with the customer attached.
    ready = make_order.call([ [ x_burger, 1 ], [ batata_frita, 1 ], [ suco, 2 ] ], customer: maria)
    OrderLifecycle.new(ready, cashier).record_payment!(
      ready.payments.build(method: "card", amount: ready.total)
    )
    OrderLifecycle.new(ready, kitchen_user).start_cooking!
    OrderLifecycle.new(ready, kitchen_user).mark_ready!

    # Completed — feeds the customer history and today's revenue.
    completed = make_order.call([ [ suco, 3 ] ], customer: maria)
    OrderLifecycle.new(completed, cashier).record_payment!(
      completed.payments.build(method: "pix", amount: completed.total)
    )
    OrderLifecycle.new(completed, kitchen_user).start_cooking!
    OrderLifecycle.new(completed, kitchen_user).mark_ready!
    OrderLifecycle.new(completed, cashier).complete!
  end

  # Seed one delivery order (once) so the kitchen delivery rail and the order
  # ticket show the address. Tagged via gateway_reference for idempotency.
  unless business.payments.exists?(gateway_reference: "demo_delivery")
    kitchen_user = User.find_by!(email: "kitchen@foodtruck.local")
    maria = Customer.find_or_create_by!(business: business, phone: "11912345678") do |c|
      c.name = "Maria Silva"
    end

    delivery_order = business.orders.build(customer: maria)
    [ x_burger, batata_frita ].each do |product|
      delivery_order.order_items.build(
        product: product, product_name: product.name, unit_price: product.price, quantity: 1
      )
    end
    delivery_order.order_type = "delivery"
    delivery_order.delivery_fee = business.delivery_fee
    delivery_order.subtotal = delivery_order.order_items.sum { |item| (item.unit_price * item.quantity).round(2) }
    delivery_order.total = (delivery_order.subtotal + delivery_order.delivery_fee).round(2)
    delivery_order.build_delivery_address(
      street: "Rua Augusta", number: "455", neighborhood: "Consolação",
      city: "São Paulo", state: "SP", zip: "01304-000"
    )
    delivery_order.save!
    OrderLifecycle.new(delivery_order, cashier).confirm!
    delivery_order.create_delivery!
    OrderLifecycle.new(delivery_order, cashier).record_payment!(
      delivery_order.payments.build(method: "pix", amount: delivery_order.total, gateway_reference: "demo_delivery")
    )
    OrderLifecycle.new(delivery_order, kitchen_user).start_cooking!
  end

  puts "Demo data ensured: category=#{category.name}, products=#{products.size}, " \
       "gateway_enabled=#{IntegrationSetting.enabled.any?}, " \
       "open_shift=#{CashRegister.open.any?}, " \
       "orders=#{business.orders.count}"
end
