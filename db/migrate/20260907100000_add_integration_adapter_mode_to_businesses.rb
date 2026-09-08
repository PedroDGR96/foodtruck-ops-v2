class AddIntegrationAdapterModeToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :integration_adapter_mode, :string, null: false, default: "mock"
    add_index :businesses, :integration_adapter_mode
  end
end
