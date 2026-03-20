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
      user_id = env["analytics.user_id"] # set by Trackable concern
      session_id = request.session.id&.to_s

      AnalyticsClient.track(
        event_type: "pageview",
        request: request,
        status: status,
        duration_ms: duration,
        user_id: user_id,
        session_id: session_id
      )
    end

    [status, headers, response]
  rescue => e
    # Never break the app if analytics fails
    Rails.logger.error("[Analytics] Middleware error: #{e.message}")
    raise e if status.nil? # re-raise if the app itself errored
    [status, headers, response]
  end

  private

  def skip_tracking?(request)
    SKIP_PATHS.any? { |p| request.path.start_with?(p) }
  end
end
