require "test_helper"

class AnalyticsBufferTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    # Reset the singleton buffer for each test
    @buffer = AnalyticsBuffer.instance
    @buffer.flush # clear any existing events
  end

  test "push adds event and flush enqueues a batch job" do
    assert_enqueued_with(job: AnalyticsBatchJob) do
      5.times { |i| @buffer.push({ event_type: "test", index: i }) }
      @buffer.flush
    end
  end

  test "flush does nothing when buffer is empty" do
    assert_no_enqueued_jobs(only: AnalyticsBatchJob) do
      @buffer.flush
    end
  end

  test "auto-flushes when buffer reaches MAX_BUFFER_SIZE" do
    assert_enqueued_with(job: AnalyticsBatchJob) do
      AnalyticsBuffer::MAX_BUFFER_SIZE.times do |i|
        @buffer.push({ event_type: "test", index: i })
      end
    end
  end
end
