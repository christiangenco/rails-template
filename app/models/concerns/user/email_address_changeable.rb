module User::EmailAddressChangeable
  EMAIL_CHANGE_TOKEN_PURPOSE = "change_email_address"
  EMAIL_CHANGE_TOKEN_EXPIRATION = 30.minutes

  extend ActiveSupport::Concern

  included do
    def self.verify_email_change_token(token)
      parsed = SignedGlobalID.parse(token, for: EMAIL_CHANGE_TOKEN_PURPOSE)
      return nil unless parsed

      user = parsed.find
      return nil unless user

      old_email = parsed.params&.fetch("old_email", nil)
      new_email = parsed.params&.fetch("new_email", nil)

      # Verify user's email hasn't changed since token was generated
      return nil if user.email != old_email

      { user: user, old_email: old_email, new_email: new_email }
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  def generate_email_change_token(to:, expires_in: EMAIL_CHANGE_TOKEN_EXPIRATION)
    to_sgid(
      for: EMAIL_CHANGE_TOKEN_PURPOSE,
      expires_in: expires_in,
      old_email: email,
      new_email: to
    ).to_s
  end

  def send_email_change_confirmation(new_email)
    token = generate_email_change_token(to: new_email)
    UserMailer.email_change_confirmation(user: self, new_email: new_email, token: token).deliver_later
  end

  def change_email_address!(new_email)
    old_email = email
    update!(email: new_email)
    UserMailer.email_changed_notification(user: self, old_email: old_email).deliver_later
  end
end
