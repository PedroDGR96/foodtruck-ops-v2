# Devise memoizes configure_warden! from its first invocation. The Warden::Manager
# middleware is built lazily on the first request and its config is assigned to
# `Devise.warden_config` before routes may be finalized — and Warden::Proxy dups
# that config at request start, so strategies must already be registered on the
# serving manager config. Force route loading at boot (see config/application.rb)
# so mappings exist, and re-run the (idempotent) configure_warden! body whenever
# the warden config is (re)assigned so scope strategies are always present.
orig_configure_warden = Devise.method(:configure_warden!)
Devise.define_singleton_method(:configure_warden!) do
  Devise.class_variable_set(:@@warden_configured, false) if Devise.class_variable_defined?(:@@warden_configured)
  orig_configure_warden.call
end

orig_setter = Devise.method(:warden_config=)
Devise.define_singleton_method(:warden_config=) do |config|
  orig_setter.call(config)
  Devise.configure_warden!
end
