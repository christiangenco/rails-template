require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "mail_check sends a plain-text message to the given address" do
    mail = ApplicationMailer.mail_check(to: "christian@gxb.vc")

    assert_equal [ "christian@gxb.vc" ], mail.to
    assert_match(/mail check/i, mail.subject)
    assert_match "text/plain", mail.content_type
  end
end
