class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  # Used by bin/mail-check to prove mail delivery works after a deploy.
  def mail_check(to:)
    mail(
      to: to,
      subject: "Mail check — #{Time.current.utc.iso8601}",
      body: "This is an automated check that mail delivery works. Sent by bin/mail-check.",
      content_type: "text/plain"
    )
  end
end
