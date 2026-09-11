# frozen_string_literal: true

require "rails_helper"

# Every factory must be able to produce a valid, persistable record against a
# single shared tenant, in its default state and for every trait. This guards
# against factories silently drifting out of sync with model validations (e.g.
# the Payment amount <= remaining balance rule, BusinessScoped's
# business_id == Current.business_id check, Order totals_consistent, and the
# single-open-shift cash register rule).
#
# Shape notes:
# * Runs inside Tenancy.with_business (RLS requires it) and passes one shared
#   business everywhere; the factories' own to_create never sees a tenant
#   mismatch.
# * Association-bearing factories are handed explicit shared parents (order,
#   order_item, cash_register) so a nested association cannot spawn its own
#   fresh business and trip "business must match the current business".
# * User-bearing factories get an explicit user with a RANDOM email because
#   User#email is globally unique (unscoped: true) and seed data already holds
#   userN@example.test rows, which collides with the factory's per-process
#   sequence when the lint runs standalone. A fresh user per created record
#   (never shared across traits) keeps cash_register's one-open-shift-per-user
#   rule and other per-user pins from interfering.
RSpec.describe "Factory lint", type: :model do
  TENANT_ROOT = :business.freeze
  ORDER_DEPENDENT = %i[payment delivery delivery_address order_event order_item].freeze
  ORDER_ITEM_ADDON = :order_item_addon
  CASH_MOVEMENT = :cash_movement
  SKIP_TRAITS = %i[with_user].freeze

  let(:business) { create(:business, name: "Lint #{SecureRandom.hex(4)}") }

  def unique_user
    create(:user, business: business, email: "lint-#{SecureRandom.hex(6)}@example.test")
  end

  def options_for(name)
    opts = { business: business, user: unique_user }
    opts[:order] = create(:order, business: business, total: 100.0, user: unique_user) if name == :payment
    opts
  end

  it "persists every factory against the shared tenant" do
    Tenancy.with_business(business) do
      order = create(:order, business: business, user: unique_user)
      order_item = create(:order_item, business: business, order: order)
      cash_register = create(:cash_register, business: business, user: unique_user)

      FactoryBot.factories.map(&:name).sort.each do |name|
        next if name == TENANT_ROOT

        opts = options_for(name)
        expect do
          if name == :payment
            create(:payment, business: business, order: opts[:order])
          elsif name == :user
            create(:user, business: business, email: "lint-#{SecureRandom.hex(6)}@example.test")
          elsif name == :order
            create(:order, business: business, user: opts[:user])
          elsif name == :order_item
            create(:order_item, business: business, order: order_item.order)
          elsif name == :order_item_addon
            create(:order_item_addon, business: business, order_item: order_item)
          elsif name == :cash_movement
            create(:cash_movement, business: business, cash_register: cash_register)
          elsif name == :cash_register
            create(:cash_register, business: business, user: opts[:user])
          elsif ORDER_DEPENDENT.include?(name)
            create(name, business: business, order: order)
          else
            create(name, business: business)
          end
        end.not_to raise_error, "#{name} should persist"
      end
    end
  end

  it "persists every trait of every factory against the shared tenant" do
    Tenancy.with_business(business) do
      order = create(:order, business: business, user: unique_user)
      order_item = create(:order_item, business: business, order: order)
      cash_register = create(:cash_register, business: business, user: unique_user)

      FactoryBot.factories.map(&:name).sort.each do |name|
        next if name == TENANT_ROOT

        traits = FactoryBot.factories[name].defined_traits_names.map(&:to_sym) - SKIP_TRAITS
        traits.each do |trait|
          opts = options_for(name)
          expect do
            if name == :payment
              create(:payment, trait, business: business, order: opts[:order])
            elsif name == :user
              create(:user, trait, business: business, email: "lint-#{SecureRandom.hex(6)}@example.test")
            elsif name == :order
              create(:order, trait, business: business, user: opts[:user],
                                     delivery_address: create(:delivery_address, business: business, order: order))
            elsif name == :order_item
              create(:order_item, trait, business: business, order: order)
            elsif name == :order_item_addon
              create(:order_item_addon, trait, business: business, order_item: order_item)
            elsif name == :cash_movement
              create(:cash_movement, trait, business: business, cash_register: cash_register)
            elsif name == :cash_register
              create(:cash_register, trait, business: business, user: opts[:user])
            elsif ORDER_DEPENDENT.include?(name)
              create(name, trait, business: business, order: order)
            else
              create(name, trait, business: business)
            end
          end.not_to raise_error, "#{name} with trait #{trait} should persist"
        end
      end
    end
  end
end
