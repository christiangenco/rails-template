require "test_helper"

class AnalyticsClientTest < ActiveSupport::TestCase
  test "track does nothing when analytics is disabled" do
    assert_not Rails.application.config.analytics.enabled

    request = mock("request")
    # Should not call AnalyticsBuffer at all
    AnalyticsBuffer.instance.expects(:push).never

    AnalyticsClient.track(event_type: "test", request: request)
  end

  test "track pushes to buffer when analytics is enabled" do
    Rails.application.config.analytics.enabled = true
    Rails.application.config.analytics.url = "https://analytics.gxb.vc/api/v1/events"

    request = mock("request")
    request.stubs(:path).returns("/test")
    request.stubs(:method).returns("GET")
    request.stubs(:remote_ip).returns("127.0.0.1")
    request.stubs(:user_agent).returns("TestAgent")
    request.stubs(:referrer).returns(nil)
    request.stubs(:params).returns({})
    request.stubs(:request_id).returns("abc-123")
    request.stubs(:session).returns({})

    AnalyticsBuffer.instance.expects(:push).once

    AnalyticsClient.track(event_type: "pageview", request: request)
  ensure
    Rails.application.config.analytics.enabled = false
  end
end
