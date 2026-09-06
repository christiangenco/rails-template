require "test_helper"

class AnalyticsMiddlewareTest < ActionDispatch::IntegrationTest
  # Force this constant's Zeitwerk autoload to happen now, before any test
  # below stubs Process.clock_gettime. AnalyticsMiddleware itself is already
  # require_relative'd eagerly by config/initializers/analytics.rb, but
  # AnalyticsClient is not. Whichever test method here is the first to
  # reference AnalyticsClient (via `.stubs(:track)`) would otherwise trigger
  # that autoload's own require path lazily inside the stubbed window —
  # Bootsnap's compile-cache staleness check calls
  # Process.clock_gettime(CLOCK_MONOTONIC) as a side effect of that require,
  # stealing the queued "start" tick and making duration-sensitive tests
  # flaky depending on random test order.
  AnalyticsClient

  test "requests succeed even when analytics is disabled" do
    assert_not Rails.application.config.analytics.enabled,
      "Analytics should be disabled in test"

    get "/"
    assert_response :success
  end

  test "asset requests are not tracked" do
    get "/assets/nonexistent.js"
    # 404 is expected — just verifying the skip logic doesn't crash
    assert_response :not_found
  end

  test "health check requests are not tracked" do
    get "/up"
    assert_response :success
  end

  test "slow requests also report a SlowRequest exception event" do
    Rails.application.config.analytics.enabled = true
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 2.5)

    calls = []
    AnalyticsClient.stubs(:track).with { |**attrs| calls << attrs; true }

    env = Rack::MockRequest.env_for("/properties/142")
    env["action_dispatch.request.path_parameters"] = { controller: "properties", action: "show" }
    middleware = AnalyticsMiddleware.new(->(_env) { [ 200, {}, [ "ok" ] ] })
    middleware.call(env)

    assert_equal 2, calls.size
    assert_equal "pageview", calls[0][:event_type]
    assert_equal "exception", calls[1][:event_type]
    assert_equal "SlowRequest", calls[1][:error_class]
    assert calls[1][:duration_ms] >= AnalyticsMiddleware::SLOW_MS
    assert_not calls[1].key?(:backtrace)
  ensure
    Rails.application.config.analytics.enabled = false
  end

  test "fast requests only report the pageview event" do
    Rails.application.config.analytics.enabled = true
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 0.1)

    calls = []
    AnalyticsClient.stubs(:track).with { |**attrs| calls << attrs; true }

    middleware = AnalyticsMiddleware.new(->(_env) { [ 200, {}, [ "ok" ] ] })
    middleware.call(Rack::MockRequest.env_for("/"))

    assert_equal 1, calls.size
    assert_equal "pageview", calls[0][:event_type]
  ensure
    Rails.application.config.analytics.enabled = false
  end

  test "a slow 500 does not also file a SlowRequest, since the error subscriber already reports it" do
    Rails.application.config.analytics.enabled = true
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 2.5)

    calls = []
    AnalyticsClient.stubs(:track).with { |**attrs| calls << attrs; true }

    middleware = AnalyticsMiddleware.new(->(_env) { [ 500, {}, [ "boom" ] ] })
    middleware.call(Rack::MockRequest.env_for("/"))

    assert_equal [ "pageview" ], calls.map { |c| c[:event_type] }
  ensure
    Rails.application.config.analytics.enabled = false
  end

  test "a slow 404 does not file a SlowRequest, since a missing route is not a performance bug" do
    Rails.application.config.analytics.enabled = true
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 2.5)

    calls = []
    AnalyticsClient.stubs(:track).with { |**attrs| calls << attrs; true }

    middleware = AnalyticsMiddleware.new(->(_env) { [ 404, {}, [ "not found" ] ] })
    middleware.call(Rack::MockRequest.env_for("/nope"))

    assert_equal [ "pageview" ], calls.map { |c| c[:event_type] }
  ensure
    Rails.application.config.analytics.enabled = false
  end

  test "a slow multipart upload does not file a SlowRequest, since a large upload is slow by nature" do
    Rails.application.config.analytics.enabled = true
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 2.5)

    calls = []
    AnalyticsClient.stubs(:track).with { |**attrs| calls << attrs; true }

    env = Rack::MockRequest.env_for(
      "/uploads", method: "POST", "CONTENT_TYPE" => "multipart/form-data; boundary=xyz"
    )
    middleware = AnalyticsMiddleware.new(->(_env) { [ 200, {}, [ "ok" ] ] })
    middleware.call(env)

    assert_equal [ "pageview" ], calls.map { |c| c[:event_type] }
  ensure
    Rails.application.config.analytics.enabled = false
  end

  test "a slow request names controller#action, not the raw path, so two ids on the same route are one issue" do
    Rails.application.config.analytics.enabled = true
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 2.5)

    calls = []
    AnalyticsClient.stubs(:track).with { |**attrs| calls << attrs if attrs[:event_type] == "exception"; true }

    env = Rack::MockRequest.env_for("/properties/142")
    env["action_dispatch.request.path_parameters"] = { controller: "properties", action: "show" }
    AnalyticsMiddleware.new(->(_env) { [ 200, {}, [ "ok" ] ] }).call(env)

    assert_equal "GET properties#show took 2500ms", calls.first[:error_message]
  ensure
    Rails.application.config.analytics.enabled = false
  end

  test "a slow request with no route params falls back to just the request method" do
    Rails.application.config.analytics.enabled = true
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 2.5)

    calls = []
    AnalyticsClient.stubs(:track).with { |**attrs| calls << attrs if attrs[:event_type] == "exception"; true }

    AnalyticsMiddleware.new(->(_env) { [ 200, {}, [ "ok" ] ] }).call(Rack::MockRequest.env_for("/properties/142"))

    assert_equal "GET took 2500ms", calls.first[:error_message]
  ensure
    Rails.application.config.analytics.enabled = false
  end

  test "slow_sql collected on the env rides along in the SlowRequest properties" do
    Rails.application.config.analytics.enabled = true
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 2.5)

    calls = []
    AnalyticsClient.stubs(:track).with { |**attrs| calls << attrs if attrs[:event_type] == "exception"; true }

    env = Rack::MockRequest.env_for("/properties/142")
    env["analytics.slow_sql"] = [ { name: "Property Load", ms: 150, sql: "SELECT ?" } ]
    AnalyticsMiddleware.new(->(_env) { [ 200, {}, [ "ok" ] ] }).call(env)

    assert_equal [ { name: "Property Load", ms: 150, sql: "SELECT ?" } ], calls.first[:properties][:slow_sql]
  ensure
    Rails.application.config.analytics.enabled = false
  end

  test "the sql.active_record subscriber stops collecting at 20 entries per request" do
    request = ActionDispatch::TestRequest.create
    controller = Struct.new(:request).new(request)

    ActiveSupport::ExecutionContext.set(controller: controller) do
      25.times { |i| publish_slow_query("query #{i}") }
    end

    assert_equal 20, request.env["analytics.slow_sql"].size
  end

  private

  # A real >100ms query would work too, but would make this test slow for no
  # benefit: publish_event lets us hand the notification a fabricated
  # duration directly, without sleeping.
  def publish_slow_query(sql)
    start = Time.now
    event = ActiveSupport::Notifications::Event.new(
      "sql.active_record", start, start + 0.15, nil,
      name: "Load", sql: sql, cached: false
    )
    ActiveSupport::Notifications.publish_event(event)
  end
end
