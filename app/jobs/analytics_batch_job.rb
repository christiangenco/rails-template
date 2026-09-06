class AnalyticsBatchJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |_job, error|
    Rails.logger.error("[Analytics] dropped batch: #{error.class}: #{error.message}")
  end

  def perform(events)
    AnalyticsClient.post_batch(events)
  end
end
