business = Business.find_by!(name: "FoodTruck Ops")
Tenancy.with_business(business) do
  category = Category.find_or_create_by!(name: "Lanches") do |c|
    c.business = business
  end

  items = [
    { name: "X-Burger", price: 28.90 },
    { name: "Batata Frita", price: 15.00 },
    { name: "Suco de Laranja", price: 9.50 }
  ]
  items.each do |item|
    Product.find_or_create_by!(business: business, name: item[:name]) do |p|
      p.category = category
      p.price = item[:price]
    end
  end

  IntegrationSetting.find_or_create_by!(business: business, provider_key: "payment_gateway") do |s|
    s.credentials = { "mock": true, "endpoint": "https://payments.example.test" }
    s.enabled = true
  end

  cashier = User.find_by!(email: "cashier@foodtruck.local")
  CashRegister.find_or_create_by!(business: business, user: cashier, status: :open) do |r|
    r.opened_at = Time.current
    r.opening_balance = 100.00
  end

  puts "Demo data ensured: category=#{category.name}, products=#{items.size}, " \
       "gateway_enabled=#{IntegrationSetting.enabled.any?}, " \
       "open_shift=#{CashRegister.open.any?}"
end
