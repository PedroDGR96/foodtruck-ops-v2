class AddNumberToOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :orders, :number, :bigint

    # Backfill: sequential numbering per business, oldest order first.
    execute <<~SQL
      UPDATE orders o
      SET number = sub.rn
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY business_id ORDER BY created_at, id) AS rn
        FROM orders
      ) sub
      WHERE sub.id = o.id;
    SQL

    change_column_null :orders, :number, false
    add_index :orders, [ :business_id, :number ], unique: true
  end

  def down
    remove_index :orders, [ :business_id, :number ]
    remove_column :orders, :number
  end
end
