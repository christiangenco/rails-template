require "test_helper"

class AnalyticsClientTest < ActiveSupport::TestCase
  teardown do
    Rails.application.config.analytics.enabled = false
  end

  test "track does nothing when analytics is disabled" do
    assert_not Rails.application.config.analytics.enabled

    request = mock("request")
    # Should not call AnalyticsBuffer at all
    AnalyticsBuffer.instance.expects(:push).never

    AnalyticsClient.track(event_type: "test", request: request)
  end

  test "track pushes to buffer when analytics is enabled" do
    enable_analytics

    AnalyticsBuffer.instance.expects(:push).once

    AnalyticsClient.track(event_type: "pageview", request: stub_request_object)
  end

  test "track works without a request, for jobs and mailers" do
    enable_analytics
    payload = nil
    AnalyticsBuffer.instance.stubs(:push).with { |p| payload = p; true }

    AnalyticsClient.track(event_type: "exception", error_class: "Notice", error_message: "hi")

    assert_equal "exception", payload[:event_type]
    assert_not payload.key?(:path)
  end

  test "explicit attributes win over the request" do
    enable_analytics
    payload = nil
    AnalyticsBuffer.instance.stubs(:push).with { |p| payload = p; true }

    AnalyticsClient.track(event_type: "exception", request: stub_request_object, path: "/api/documents", method: "POST")

    assert_equal "/api/documents", payload[:path]
    assert_equal "POST", payload[:method]
  end

  test "notify defaults a string to error_class Notice and does not raise into the caller" do
    enable_analytics
    payload = nil
    AnalyticsBuffer.instance.stubs(:push).with { |p| payload = p; true }

    assert_nothing_raised { AnalyticsClient.notify("something broke") }

    assert_equal "Notice", payload[:error_class]
    assert_equal "something broke", payload[:error_message]
  end

  test "notify swallows failures instead of raising into the caller" do
    enable_analytics
    AnalyticsBuffer.instance.stubs(:push).raises(StandardError, "buffer down")

    assert_nothing_raised { AnalyticsClient.notify(RuntimeError.new("oops")) }
  end

  test "post_batch raises on a non-2xx response so the job retries" do
    enable_analytics
    Net::HTTP.any_instance.stubs(:request).returns(Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error"))

    assert_raises(RuntimeError) { AnalyticsClient.post_batch([ { event_type: "exception" } ]) }
  end

  test "post_batch does not raise on a 2xx response" do
    enable_analytics
    Net::HTTP.any_instance.stubs(:request).returns(Net::HTTPOK.new("1.1", "200", "OK"))

    assert_nothing_raised { AnalyticsClient.post_batch([ { event_type: "exception" } ]) }
  end

  private

  def enable_analytics
    Rails.application.config.analytics.enabled = true
    Rails.application.config.analytics.url = "https://analytics.gxb.vc/api/v1/events"
  end

  def stub_request_object
    request = mock("request")
    request.stubs(:path).returns("/test")
    request.stubs(:method).returns("GET")
    request.stubs(:remote_ip).returns("127.0.0.1")
    request.stubs(:user_agent).returns("TestAgent")
    request.stubs(:referrer).returns(nil)
    request.stubs(:params).returns({})
    request.stubs(:request_id).returns("abc-123")
    request.stubs(:session).returns({})
    request
  end
end
