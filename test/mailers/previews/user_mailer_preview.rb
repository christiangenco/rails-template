# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def email_change_confirmation
    user = User.first || User.new(email: "user@example.com", name: "John Doe")
    new_email = "newemail@example.com"
    token = user.generate_email_change_token(to: new_email)
    
    UserMailer.email_change_confirmation(
      user: user,
      new_email: new_email,
      token: token
    )
  end

  def email_changed_notification
    user = User.first || User.new(email: "newemail@example.com", name: "John Doe")
    old_email = "oldemail@example.com"
    
    UserMailer.email_changed_notification(
      user: user,
      old_email: old_email
    )
  end
end
