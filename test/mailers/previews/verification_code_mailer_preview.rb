class VerificationCodeMailerPreview < ActionMailer::Preview
  def verification_email
    user = User.first || User.new(email: "test@example.com")
    verification_code = VerificationCode.new(user: user, code: "ABC123", expires_at: 15.minutes.from_now)
    VerificationCodeMailer.verification_email(verification_code)
  end
end
