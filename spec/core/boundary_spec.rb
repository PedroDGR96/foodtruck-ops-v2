# frozen_string_literal: true

require "rails_helper"

RSpec.describe "core boundary" do
  # Tier 2 (vertical) constants that must never be referenced from app/core.
  # See docs/CORE_CONTRACT.md. Customer is listed conservatively until its
  # classification is settled.
  FORBIDDEN = %w[
    Product Category MenuItem MenuSection MenuAddon Addon
    KitchenOrder KitchenStation DeliveryRoute DeliveryRun
    PosSession PosOrder CashRegister CashMovement CashDrawer
    Integration WebhookEndpoint Customer
  ].freeze

  core_files = Dir[Rails.root.join("app/core/**/*.rb")].sort

  it "has core files to guard" do
    expect(core_files).not_to be_empty
  end

  it "never references vertical constants" do
    violations = core_files.filter_map do |path|
      offenders = File.readlines(path).each_with_index.filter_map do |line, idx|
        next unless (hit = FORBIDDEN.find { |name| line.match?(/\b#{name}\b/) })

        "#{File.basename(path)}:#{idx + 1} references #{hit}"
      end
      offenders unless offenders.empty?
    end.flatten

    expect(violations).to be_empty,
                          "app/core must not depend on verticals:\n#{violations.join("\n")}"
  end
end
