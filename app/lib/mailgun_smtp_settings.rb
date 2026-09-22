# Fails app boot with one clear sentence instead of starting with a nil SMTP
# password and letting every mailer job fail authentication silently later.
class MailgunSmtpSettings
  MISSING_CREDENTIAL_MESSAGE =
    "Missing mailgun.smtp_password credential. Run `bin/rails credentials:edit` to add it, " \
    "or re-run `bin/setup-new-project --smtp-password ...` to configure mail for this app."

  # Plain Ruby, not `.blank?`: config/environments/production.rb requires this
  # file and calls .for before ActiveSupport's core extensions are loaded.
  def self.for(user_name:)
    password = Rails.application.credentials.dig(:mailgun, :smtp_password)
    raise MISSING_CREDENTIAL_MESSAGE if password.to_s.empty?

    {
      port: 587,
      address: "smtp.mailgun.org",
      user_name: user_name,
      password: password,
      authentication: :plain
    }
  end
end
