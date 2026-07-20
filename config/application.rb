require_relative "boot"

require "rails"
require_relative "../app/middleware/stack_obfuscation_middleware"
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

module RailsTemplate
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # rails_icons reads SVGs from disk (File.read), not through Propshaft, so keep the
    # icon set out of the asset digest — precompile shouldn't fingerprint ~1300 files.
    # NOTE: must live here, not in config/initializers/assets.rb — Propshaft reads
    # excluded_paths in an engine initializer that runs before app initializers.
    config.assets.excluded_paths = [Rails.root.join("app/assets/svg")]

    # Use vips for Active Storage image processing
    config.active_storage.variant_processor = :vips

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Reduce framework fingerprinting in default responses.
    config.middleware.delete ActionDispatch::RequestId
    config.middleware.delete Rack::Runtime
    config.middleware.insert_before 0, StackObfuscationMiddleware
  end
end
