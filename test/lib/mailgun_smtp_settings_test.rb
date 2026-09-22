require "test_helper"

class MailgunSmtpSettingsTest < ActiveSupport::TestCase
  test "raises a clear message when the credential is missing" do
    Rails.application.credentials.stubs(:dig).with(:mailgun, :smtp_password).returns(nil)

    error = assert_raises(RuntimeError) { MailgunSmtpSettings.for(user_name: "myapp@gxb.vc") }
    assert_equal MailgunSmtpSettings::MISSING_CREDENTIAL_MESSAGE, error.message
  end

  test "builds Mailgun SMTP settings when the credential is present" do
    Rails.application.credentials.stubs(:dig).with(:mailgun, :smtp_password).returns("s3cret")

    settings = MailgunSmtpSettings.for(user_name: "myapp@gxb.vc")

    assert_equal "smtp.mailgun.org", settings[:address]
    assert_equal 587, settings[:port]
    assert_equal "myapp@gxb.vc", settings[:user_name]
    assert_equal "s3cret", settings[:password]
    assert_equal :plain, settings[:authentication]
  end
end
