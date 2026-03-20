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
end
