require "rails_helper"
require "tmpdir"
require Rails.root.join("lib/generators/tenant_model/tenant_model_generator")

RSpec.describe TenantModelGenerator do
  it "generates a business-scoped model and RLS-backed migration" do
    Dir.mktmpdir do |directory|
      generator = described_class.new([ "Order" ], {}, destination_root: directory)

      generator.invoke_all

      expect(File.read(File.join(directory, "app/models/order.rb"))).to include("BusinessScoped")
      migration = Dir[File.join(directory, "db/migrate/*_create_orders.rb")].fetch(0)
      expect(File.read(migration)).to include("Tenancy::TenantRls.install!")
    end
  end

  it "uses Rails migration numbering" do
    Dir.mktmpdir do |directory|
      expect(described_class.next_migration_number(directory)).to match(/\A\d+\z/)
    end
  end
end
