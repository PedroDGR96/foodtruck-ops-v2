class CreateTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :tokens, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :business, null: false, type: :uuid, foreign_key: true
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :scope, null: false
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at
      t.datetime :last_used_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :tokens, :token_digest, unique: true
  end
end
