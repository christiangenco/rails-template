class AnalyticsBatchJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on Net::OpenTimeout, Net::ReadTimeout

  def perform(events)
    AnalyticsClient.post_batch(events)
  end
end
