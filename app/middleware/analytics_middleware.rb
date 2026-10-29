class AnalyticsMiddleware
  SKIP_PATHS = %w[/health /assets /packs].freeze
  SLOW_MS = 2_000

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
      session_id = request.session.id&.to_s rescue nil

      AnalyticsClient.track(
        event_type: "pageview",
        request: request,
        status: status,
        duration_ms: duration,
        user_id: user_id,
        session_id: session_id
      )

      if duration >= SLOW_MS && status.to_i.between?(200, 399) && !multipart?(request)
        AnalyticsClient.track(
          event_type: "exception",
          request: request,
          status: status,
          duration_ms: duration,
          user_id: user_id,
          session_id: session_id,
          error_class: "SlowRequest",
          error_message: "#{controller_action(env)} took #{duration}ms",
          properties: { slow_sql: env["analytics.slow_sql"] }.compact
        )
      end
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

  def multipart?(request)
    request.media_type == "multipart/form-data"
  end

  # Route identity instead of the raw path, so /properties/142 and
  # /properties/7 fingerprint as the same issue instead of two.
  def controller_action(env)
    path_params = env["action_dispatch.request.path_parameters"]
    return env["REQUEST_METHOD"] unless path_params

    "#{env["REQUEST_METHOD"]} #{path_params[:controller]}##{path_params[:action]}"
  end
end
