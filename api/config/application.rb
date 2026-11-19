require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module LegalMatterApi
  class Application < Rails::Application
    config.load_defaults 7.2
    config.api_only = true
    config.autoload_lib(ignore: %w[tasks])
    config.time_zone = "Eastern Time (US & Canada)"

    # Redis-backed cache (matter summaries)
    config.cache_store = :redis_cache_store, {
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
      namespace: "legal-matter-api-#{Rails.env}"
    }
  end
end
