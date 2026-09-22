# The default delivery method for a fresh clone, and for any app whose
# bin/setup-new-project ran with --no-mail. Raises the first time a mailer is
# actually used, instead of failing SMTP auth silently against an
# unconfigured localhost server.
class UnconfiguredMailDelivery
  MESSAGE =
    "Mail is not configured for this app (bin/setup-new-project has not been run with " \
    "--smtp-password, or was run with --no-mail). Re-run it with --smtp-password " \
    "(or set MAILGUN_SMTP_PASSWORD) to enable mail."

  def initialize(*)
  end

  def deliver!(mail)
    raise MESSAGE
  end
end
