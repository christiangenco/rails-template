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

  test "auto-flushes when buffer reaches FLUSH_THRESHOLD" do
    assert_enqueued_with(job: AnalyticsBatchJob) do
      AnalyticsBuffer::FLUSH_THRESHOLD.times do |i|
        @buffer.push({ event_type: "test", index: i })
      end
    end
  end

  test "concurrent flushes send each event exactly once" do
    100.times { |i| @buffer.push({ event_type: "test", index: i }) }

    4.times.map { Thread.new { @buffer.flush } }.each(&:join)

    sent = enqueued_jobs.select { |job| job["job_class"] == "AnalyticsBatchJob" }
                        .flat_map { |job| job["arguments"].first }
    assert_equal 100, sent.size
    assert_equal 100, sent.uniq.size
  end

  test "an event that arrives during a flush is kept for the next flush" do
    @buffer.push({ event_type: "first" })

    buffer = @buffer # define_singleton_method rebinds self, so close over a local
    with_enqueue ->(_events) { buffer.push({ event_type: "second" }); true } do
      @buffer.flush
    end

    assert_enqueued_with(job: AnalyticsBatchJob, args: [ [ { event_type: "second" } ] ]) do
      @buffer.flush
    end
  end

  test "a failed enqueue puts the batch back" do
    @buffer.push({ event_type: "test" })

    with_enqueue ->(_events) { raise "queue down" } do
      assert_nothing_raised { @buffer.flush }
    end

    assert_enqueued_with(job: AnalyticsBatchJob, args: [ [ { event_type: "test" } ] ]) do
      @buffer.flush
    end
  end

  test "an aborted enqueue puts the batch back" do
    @buffer.push({ event_type: "test" })

    with_enqueue(->(_events) { false }) { @buffer.flush }

    assert_enqueued_with(job: AnalyticsBatchJob, args: [ [ { event_type: "test" } ] ]) do
      @buffer.flush
    end
  end

  test "an unserializable batch is dropped instead of blocking later flushes" do
    @buffer.push({ event_type: "poison" })

    with_enqueue ->(_events) { raise ActiveJob::SerializationError.new(Object.new) } do
      assert_nothing_raised { @buffer.flush }
    end

    assert_no_enqueued_jobs(only: AnalyticsBatchJob) { @buffer.flush }
  end

  test "the buffer never grows past BUFFER_CAP" do
    with_enqueue ->(_events) { raise "queue down" } do
      (AnalyticsBuffer::BUFFER_CAP + 100).times { |i| @buffer.push({ event_type: "test", index: i }) }
    end

    captured = nil
    with_enqueue(->(batch) { captured = batch; true }) { @buffer.flush }
    assert_equal AnalyticsBuffer::BUFFER_CAP, captured.size
  end

  private

  # perform_later is a class method inherited from ActiveJob, so defining one
  # here and removing it after is enough to fake a queue that fails or races.
  def with_enqueue(impl)
    AnalyticsBatchJob.define_singleton_method(:perform_later, &impl)
    yield
  ensure
    AnalyticsBatchJob.singleton_class.remove_method(:perform_later)
  end
end
