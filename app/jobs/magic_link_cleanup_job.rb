class MagicLinkCleanupJob < ApplicationJob
  queue_as :default

  def perform
    count = MagicLink.cleanup
    Rails.logger.info "Cleaned up #{count} expired magic links"
  end
end
