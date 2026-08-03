require "rails/generators"
require "rails/generators/active_record"

class TenantModelGenerator < Rails::Generators::NamedBase
  include Rails::Generators::Migration

  source_root File.expand_path("templates", __dir__)

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end

  def create_model
    template "model.rb.tt", "app/models/#{file_name}.rb"
  end

  def create_tenant_migration
    migration_template "create_tenant_model.rb.tt", "db/migrate/create_#{table_name}.rb"
  end
end
