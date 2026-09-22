require "test_helper"

class JobFailureReportingTestMailer < ApplicationMailer
  def boom
    raise "smtp boom"
  end
end

class JobFailureReportingTest < ActiveSupport::TestCase
  class BoomJob < ApplicationJob
    def perform
      raise "boom"
    end
  end

  class OtherBoomJob < ApplicationJob
    def perform
      raise TypeError, "different failure"
    end
  end

  setup { JobFailureReporting.reset! }

  test "a failed job reports exactly once" do
    Rails.error.expects(:report).once

    assert_raises(RuntimeError) { BoomJob.perform_now }
  end

  test "an identical failure within the window reports zero more times" do
    Rails.error.expects(:report).once

    assert_raises(RuntimeError) { BoomJob.perform_now }
    assert_raises(RuntimeError) { BoomJob.perform_now }
  end

  test "a different job class reports again even inside the window" do
    calls = []
    Rails.error.stubs(:report).with { |error, **| calls << error.class; true }

    assert_raises(RuntimeError) { BoomJob.perform_now }
    assert_raises(TypeError) { OtherBoomJob.perform_now }

    assert_equal [ RuntimeError, TypeError ], calls
  end

  test "the job still fails after being reported, so it lands in failed_executions" do
    Rails.error.stubs(:report)

    error = assert_raises(RuntimeError) { BoomJob.perform_now }
    assert_equal "boom", error.message
  end

  test "reports carry the job and queue in the error context" do
    context = nil
    Rails.error.stubs(:report).with { |_error, **kwargs| context = kwargs[:context]; true }

    assert_raises(RuntimeError) { BoomJob.perform_now }

    assert_instance_of BoomJob, context[:job]
  end

  test "ActionMailer::MailDeliveryJob reports an unhandled delivery failure" do
    Rails.error.expects(:report).once

    assert_raises(RuntimeError) do
      ActionMailer::MailDeliveryJob.new("JobFailureReportingTestMailer", "boom", "deliver_now", args: []).perform_now
    end
  end
end
