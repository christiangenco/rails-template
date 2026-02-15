class UserMailer < ApplicationMailer
  def email_change_confirmation(user:, new_email:, token:)
    @user = user
    @new_email = new_email
    @token = token
    @confirmation_url = users_email_address_confirmation_url(email_address_id: @token)

    mail(to: new_email, subject: "Confirm your new email address")
  end

  def email_changed_notification(user:, old_email:)
    @user = user
    @old_email = old_email

    mail(to: old_email, subject: "Your email address has been changed")
  end
end
