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

  test "a pageview on a routed request carries controller_action" do
    calls = capture_tracks

    get "/"

    assert_equal [ "pageview" ], calls.map { |c| c[:event_type] }
    assert_equal "home#index", calls.first[:controller_action]
  end

  test "a pageview on an unrouted 404 has a nil controller_action" do
    calls = capture_tracks

    get "/no-such-page-anywhere"

    assert_response :not_found
    pageview = calls.find { |c| c[:event_type] == "pageview" && c[:status].to_i == 404 }
    assert pageview, "expected a 404 pageview"
    assert_nil pageview[:controller_action]
  end

  test "a slow request sends only the pageview, with no SlowRequest exception" do
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 2.5)
    calls = capture_tracks

    env = Rack::MockRequest.env_for("/properties/142")
    env["action_dispatch.request.path_parameters"] = { controller: "properties", action: "show", id: "142" }
    AnalyticsMiddleware.new(->(_env) { [ 200, {}, [ "ok" ] ] }).call(env)

    assert_equal [ "pageview" ], calls.map { |c| c[:event_type] }
    assert_equal 2500, calls.first[:duration_ms]
    assert_equal "properties#show", calls.first[:controller_action]
  end

  test "the pageview payload is the old payload plus controller_action, nothing else" do
    Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 0.1)
    calls = capture_tracks

    env = Rack::MockRequest.env_for("/properties/142?token=secret")
    env["action_dispatch.request.path_parameters"] = { controller: "properties", action: "show", id: "142" }
    env["analytics.user_id"] = "7"
    AnalyticsMiddleware.new(->(_env) { [ 200, {}, [ "ok" ] ] }).call(env)

    assert_equal %i[controller_action duration_ms event_type request session_id status user_id], calls.first.keys.sort
    assert_equal 100, calls.first[:duration_ms]
    assert_equal "7", calls.first[:user_id]
  end

  test "the template no longer collects slow SQL for analytics" do
    request = ActionDispatch::TestRequest.create
    controller = Struct.new(:request).new(request)

    ActiveSupport::ExecutionContext.set(controller: controller) do
      start = Time.now
      ActiveSupport::Notifications.publish_event(ActiveSupport::Notifications::Event.new(
        "sql.active_record", start, start + 0.15, nil, name: "Load", sql: "SELECT 1", cached: false
      ))
    end

    assert_nil request.env["analytics.slow_sql"]
  end

  private

  def capture_tracks
    calls = []
    AnalyticsClient.stubs(:track).with { |**attrs| calls << attrs; true }
    calls
  end
end
