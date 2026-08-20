key_base = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_BASE"] ||
           Rails.application.secret_key_base ||
           "foodtruck-ops-encryption-dev-key"

config = ActiveRecord::Encryption.configure(
  primary_key: ActiveSupport::KeyGenerator.new(key_base).generate_key("primary", 32),
  deterministic_key: ActiveSupport::KeyGenerator.new(key_base).generate_key("deterministic", 32),
  key_derivation_salt: ActiveSupport::KeyGenerator.new(key_base).generate_key("salt", 32)
)
