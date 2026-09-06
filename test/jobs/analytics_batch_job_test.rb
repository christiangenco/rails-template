require "test_helper"

class AnalyticsBatchJobTest < ActiveJob::TestCase
  test "swallows the final failure instead of re-raising" do
    AnalyticsClient.stubs(:post_batch).raises(StandardError, "analytics down")

    job = AnalyticsBatchJob.new([ { event_type: "exception" } ])
    job.executions = 5 # at the attempts: 5 cap, so retry_on's block runs instead of retrying

    assert_nothing_raised { job.perform_now }
  end

  test "retries instead of raising while under the attempts cap" do
    AnalyticsClient.stubs(:post_batch).raises(StandardError, "analytics down")

    job = AnalyticsBatchJob.new([ { event_type: "exception" } ])
    job.executions = 1

    assert_enqueued_jobs 1, only: AnalyticsBatchJob do
      assert_nothing_raised { job.perform_now }
    end
  end
end
