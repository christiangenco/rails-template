Rails.application.config.analytics = ActiveSupport::OrderedOptions.new
Rails.application.config.analytics.url = ENV["ANALYTICS_URL"] # e.g. https://analytics.gxb.vc/api/v1/events
Rails.application.config.analytics.api_key = Rails.application.credentials.dig(:analytics, :api_key)
Rails.application.config.analytics.enabled = Rails.env.production? || ENV["ANALYTICS_ENABLED"] == "true"

require_relative "../../app/middleware/analytics_middleware"
Rails.application.config.middleware.use AnalyticsMiddleware

at_exit { AnalyticsBuffer.instance.flush if defined?(AnalyticsBuffer) }
