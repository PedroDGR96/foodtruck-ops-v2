class AddCashRegisterToPayments < ActiveRecord::Migration[8.1]
  def change
    add_reference :payments, :cash_register, null: true, type: :uuid, foreign_key: true
  end
end
