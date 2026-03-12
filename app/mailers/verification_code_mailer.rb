class VerificationCodeMailer < ApplicationMailer
  def verification_email(verification_code)
    @verification_code = verification_code
    @user = verification_code.user

    mail(to: @user.email, subject: "Your sign-in code is #{verification_code.code}")
  end
end
