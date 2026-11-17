class AnalyticsMiddleware
  SKIP_PATHS = %w[/health /assets /packs].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, response = @app.call(env)
    duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round

    request = ActionDispatch::Request.new(env)

    unless skip_tracking?(request)
      AnalyticsClient.track(
        event_type: "pageview",
        request: request,
        status: status,
        duration_ms: duration,
        controller_action: controller_action(env),
        user_id: env["analytics.user_id"], # set by Trackable concern
        session_id: (request.session.id&.to_s rescue nil)
      )
    end

    [ status, headers, response ]
  rescue => e
    # Never break the app if analytics fails
    Rails.logger.error("[Analytics] Middleware error: #{e.message}")
    raise e if status.nil? # re-raise if the app itself errored
    [ status, headers, response ]
  end

  private

  def skip_tracking?(request)
    SKIP_PATHS.any? { |p| request.path.start_with?(p) }
  end

  # "properties#show", so analytics can rank slow routes from pageview
  # durations without a per-request exception. nil when nothing routed (the
  # router's 404 for an unknown path); AnalyticsClient drops nil keys.
  def controller_action(env)
    path_params = env["action_dispatch.request.path_parameters"]
    return unless path_params&.key?(:controller) && path_params&.key?(:action)

    "#{path_params[:controller]}##{path_params[:action]}"
  end
end
