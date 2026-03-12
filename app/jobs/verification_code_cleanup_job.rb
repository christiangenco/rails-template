class VerificationCodeCleanupJob < ApplicationJob
  queue_as :default

  def perform
    count = VerificationCode.cleanup
    Rails.logger.info "Cleaned up #{count} expired verification codes"
  end
end
