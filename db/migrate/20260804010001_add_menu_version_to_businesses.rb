class AddMenuVersionToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :menu_version, :integer, null: false, default: 0
  end
end
