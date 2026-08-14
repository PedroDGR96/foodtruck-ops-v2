#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "config/environment"
require "factory_bot_rails"

puts "Setting up demo data..."

# Create business first (outside Tenancy context since it's self-referential)
business = FactoryBot.create(:business, name: "Burger Kingpin", timezone: "America/Sao_Paulo")
puts "  ✓ Business created: Burger Kingpin (America/Sao_Paulo)"

# Now inside Tenancy context - all tenant-scoped models
Tenancy.with_business(business) do
  # Use factory with business association and Tenancy context
  user = FactoryBot.create(:user, email: "pedro@gourmet.local", role: :owner)
  puts "  ✓ User created: #{user.name} - Owner"

  # Create categories
  factories = [
    { name: "Burgers", position: 0 },
    { name: "Pizza", position: 15 },
    { name: "Sides", position: 25 },
    { name: "Drinks", position: 30 }
  ]

  factories.each do |c|
    FactoryBot.create(:category, **c, business: business)
  end
  puts "  ✓ Categories created"

  # Create products with variants - each entry is [name, price, desc] or [name, price, desc, variant_name]
  products_data = [
    ["Burgers", "Classic Burger", 25.00],
    ["Burgers", "Chicken Sandwich", 18.90],
    ["Pizza", "Margherita", 32.00, "Traditional Italian pizza"],
    ["Sides", "French Fries", 12.00],
    ["Drinks", "Cola", 6.00]
  ]

  products_data.each do |category_name|
    category = business.categories.find_by(name: category_name)
    
    # Extract name, price, and optional description from the row
    product_row = products_data[products_data.index(category_name)..-1].first
    
    name, price, desc = product_row[0..2]
    
    product = FactoryBot.create(
      :product,
      name: name,
      description: desc,
      price: price.to_f,
      business: business,
      category: category
    )
    
    # Add a variant for some products
    if ["Classic Burger", "Margherita", "French Fries"].include?(name)
      FactoryBot.create(
        :product_variant,
        name: name.downcase.sub(/\s+/, "_").split(" ").join("_"),
        price: price * 0.95,
        stock: 20,
        business: business,
        product: product
      )
    end
    
    puts "  ✓ Product created: #{name} - R$ #{price.round(2)}"
  end

  # Create integration settings for the business
  [
    :payment_gateway,
    :messaging,
    :maps,
    :fiscal,
    :marketplace
  ].each do |provider_key|
    FactoryBot.create(:integration_setting, provider_key: provider_key, business: business)
  end
  puts "  ✓ Integration settings created"

end

puts "\n🎉 Demo data setup complete!"
