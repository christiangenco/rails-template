require "test_helper"

class AnalyticsMiddlewareTest < ActionDispatch::IntegrationTest
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

    middleware = AnalyticsMiddleware.new(->(_env) { [ 200, {}, [ "ok" ] ] })
    middleware.call(Rack::MockRequest.env_for("/"))

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
end
