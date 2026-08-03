# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
business = Business.find_or_create_by!(name: "FoodTruck Ops") do |record|
  record.currency = "BRL"
  record.timezone = "America/Sao_Paulo"
  record.active = true
end

Tenancy.with_business(business) do
  User.find_or_create_by!(email: "owner@foodtruck.local") do |user|
    user.name = "FoodTruck Owner"
    user.role = "owner"
  end
end
