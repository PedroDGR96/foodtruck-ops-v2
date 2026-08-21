# Tenancy and its Sidekiq middlewares are autoloaded from app/core/lib.
Rails.application.config.to_prepare do
  Sidekiq.configure_client do |config|
    config.client_middleware.add Tenancy::SidekiqClientMiddleware
  end

  Sidekiq.configure_server do |config|
    config.client_middleware.add Tenancy::SidekiqClientMiddleware
    config.server_middleware.add Tenancy::SidekiqServerMiddleware
  end
end
