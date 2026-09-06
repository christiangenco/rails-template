require "test_helper"

class AnalyticsErrorSubscriberTest < ActiveSupport::TestCase
  test "a job context reports a request-less exception with job metadata" do
    job = AnalyticsBatchJob.new([])
    job.executions = 2
    error = RuntimeError.new("boom")

    attrs = nil
    AnalyticsClient.expects(:notify).with { |err, **kwargs| attrs = kwargs; err == error }

    AnalyticsErrorSubscriber.new.report(
      error, handled: false, severity: :error,
      context: { job: job }, source: "application.solid_queue"
    )

    assert_nil attrs[:request]
    assert_equal "AnalyticsBatchJob", attrs[:properties][:job]
    assert_equal 2, attrs[:properties][:executions]
    assert_equal false, attrs[:properties][:handled]
  end

  test "a controller context reports with the request" do
    request = ActionDispatch::TestRequest.create("PATH_INFO" => "/widgets")
    controller = Struct.new(:request).new(request)
    error = RuntimeError.new("boom")

    attrs = nil
    AnalyticsClient.expects(:notify).with { |err, **kwargs| attrs = kwargs; err == error }

    AnalyticsErrorSubscriber.new.report(
      error, handled: true, severity: :warning,
      context: { controller: controller }, source: "application.action_dispatch"
    )

    assert_equal request, attrs[:request]
    assert_nil attrs[:properties][:job]
    assert_not attrs.key?(:path) # nothing to override, so the client reads the request
  end

  # config.exceptions_app has already rewritten the request to GET /500 by the
  # time Rails reports the error, so the issue would name the error page.
  test "an exceptions_app request reports the route that actually failed" do
    request = ActionDispatch::TestRequest.create(
      "PATH_INFO" => "/500",
      "REQUEST_METHOD" => "GET",
      "action_dispatch.original_path" => "/api/documents",
      "action_dispatch.original_request_method" => "POST"
    )
    controller = Struct.new(:request).new(request)

    attrs = nil
    AnalyticsClient.expects(:notify).with { |_err, **kwargs| attrs = kwargs; true }

    AnalyticsErrorSubscriber.new.report(
      RuntimeError.new("boom"), handled: false, severity: :error,
      context: { controller: controller }, source: "application.action_dispatch"
    )

    assert_equal "/api/documents", attrs[:path]
    assert_equal "POST", attrs[:method]
  end
end
