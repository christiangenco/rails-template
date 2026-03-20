class AnalyticsBuffer
  FLUSH_INTERVAL = 10.seconds
  MAX_BUFFER_SIZE = 50

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
      should_flush = @buffer.size >= MAX_BUFFER_SIZE
    end
    flush if should_flush
  end

  def flush
    events = nil
    @mutex.synchronize do
      events = @buffer.dup
      @buffer.clear
    end
    return if events.empty?

    AnalyticsBatchJob.perform_later(events)
  end

  private

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
