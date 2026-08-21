require_relative "boot"
require_relative "../app/middleware/tenant_middleware"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks generators])

    # Tier 1 core (see docs/CORE_CONTRACT.md): each directory is its own
    # Zeitwerk root so constants keep their top-level names (Current,
    # BusinessScoped, ...). app/core itself must never become a root.
    core_root = Rails.root.join("app/core")
    config.eager_load_paths += [ core_root.join("models"), core_root.join("models/concerns"),
                                 core_root.join("lib") ]
    config.active_job.queue_adapter = :sidekiq
    config.active_record.schema_format = :sql
    config.middleware.insert_after Warden::Manager, TenantMiddleware

    # The application is fully Brazilian Portuguese: default locale, all
    # user-facing strings, money (BRL) and date/time formats.
    config.i18n.default_locale = :"pt-BR"
    config.i18n.available_locales = %i[en] + [ :"pt-BR" ]

    # Load routes at boot so Devise mappings exist before the Warden::Manager is
    # first built; otherwise request-time proxies dup a config that has no scope
    # strategies registered (see config/initializers/devise_warden_fix.rb).
    config.after_initialize do
      Rails.application.reload_routes!
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
