class MagicLinkMailerPreview < ActionMailer::Preview
  def sign_in_instructions
    user = User.first || User.new(email: "test@example.com")
    magic_link = MagicLink.new(user: user, code: "ABC123", expires_at: 15.minutes.from_now)
    MagicLinkMailer.sign_in_instructions(magic_link)
  end
end
