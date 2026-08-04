class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users do |t|
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.integer :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip
      t.integer :failed_attempts, null: false, default: 0
      t.string :unlock_token
      t.datetime :locked_at
      t.boolean :active, null: false, default: true
    end

    add_index :users, :reset_password_token, unique: true
    add_index :users, :unlock_token, unique: true

    remove_index :users, name: "index_users_on_business_id_and_email"
    add_index :users, :email, unique: true
  end
end
