# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
business = Business.find_or_create_by!(name: "FoodTruck Ops") do |record|
  record.currency = "BRL"
  record.timezone = "America/Sao_Paulo"
  record.active = true
end

Tenancy.with_business(business) do
  owner_password = ENV.fetch("OWNER_PASSWORD", "password123")

  {
    "owner@foodtruck.local" => { name: "FoodTruck Owner", role: "owner" },
    "cashier@foodtruck.local" => { name: "Cashier", role: "cashier" },
    "kitchen@foodtruck.local" => { name: "Kitchen Staff", role: "kitchen" }
  }.each do |email, attributes|
    user = User.find_or_initialize_by(email: email)
    user.name = attributes[:name]
    user.role = attributes[:role]
    if user.encrypted_password.blank?
      user.password = owner_password
      user.password_confirmation = owner_password
    end
    user.save!
  end
end
