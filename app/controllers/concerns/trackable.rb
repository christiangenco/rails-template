module Trackable
  extend ActiveSupport::Concern

  included do
    before_action :set_analytics_user, :persist_utm_params
  end

  private

  def set_analytics_user
    # Make user_id available to the middleware
    request.env["analytics.user_id"] = current_user&.id&.to_s
  end

  def persist_utm_params
    %w[utm_source utm_medium utm_campaign].each do |param|
      session[param] ||= params[param] if params[param].present?
    end
  end

  # Track custom events from controllers:
  #   track("signup_completed", plan: "pro")
  #   track("checkout_started", properties: { amount: 99 })
  def track(event_type, **properties)
    AnalyticsClient.track(
      event_type: event_type,
      request: request,
      user_id: current_user&.id&.to_s,
      session_id: session.id&.to_s,
      properties: properties.presence
    )
  end
end
