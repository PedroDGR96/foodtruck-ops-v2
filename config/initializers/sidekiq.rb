require Rails.root.join("lib/tenancy")
require Rails.root.join("lib/tenancy/sidekiq_client_middleware")
require Rails.root.join("lib/tenancy/sidekiq_server_middleware")

Sidekiq.configure_client do |config|
  config.client_middleware.add Tenancy::SidekiqClientMiddleware
end

Sidekiq.configure_server do |config|
  config.client_middleware.add Tenancy::SidekiqClientMiddleware
  config.server_middleware.add Tenancy::SidekiqServerMiddleware
end
