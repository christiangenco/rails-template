class AnalyticsBuffer
  FLUSH_INTERVAL = 10.seconds
  FLUSH_THRESHOLD = 50
  BUFFER_CAP = 1_000
  # A batch that can't be serialized will never enqueue, so putting it back
  # would block every later flush behind it.
  POISON = [ ActiveJob::SerializationError, JSON::GeneratorError, EncodingError ].freeze

  include Singleton

  def initialize
    @buffer = []
    @mutex = Mutex.new
    start_flush_timer
  end

  def push(event)
    should_flush = false
    @mutex.synchronize do
      @buffer << event
      @buffer.shift while @buffer.size > BUFFER_CAP
      should_flush = @buffer.size >= FLUSH_THRESHOLD
    end
    flush if should_flush
  end

  # Detaches the batch under the mutex, so a concurrent flush can't send the
  # same events twice or drop events that arrived while this one was enqueuing.
  def flush
    events = @mutex.synchronize { @buffer.shift(@buffer.size) }
    return if events.empty?

    requeue(events) unless AnalyticsBatchJob.perform_later(events)
  rescue *POISON => e
    Rails.logger.error("[Analytics] dropped #{events.size} unserializable events: #{e.class}: #{e.message}")
  rescue => e
    requeue(events)
    Rails.logger.error("[Analytics] Buffer flush error: #{e.class}: #{e.message}")
  end

  private

  def requeue(events)
    @mutex.synchronize do
      @buffer.unshift(*events)
      @buffer.shift while @buffer.size > BUFFER_CAP
    end
  end

  def start_flush_timer
    Thread.new do
      loop do
        sleep FLUSH_INTERVAL
        flush
      rescue => e
        Rails.logger.error("[Analytics] Buffer flush error: #{e.message}")
      end
    end
  end
end
