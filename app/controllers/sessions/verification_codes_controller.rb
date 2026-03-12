class Sessions::VerificationCodesController < ApplicationController
  require_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: :rate_limit_exceeded
  before_action :ensure_that_email_address_pending_authentication_exists

  layout "public"

  def show
  end

  def create
    if verification_code = VerificationCode.consume(code)
      authenticate(verification_code)
    else
      redirect_to session_verification_code_path, flash: { shake: true }
    end
  end

  private

  def ensure_that_email_address_pending_authentication_exists
    unless email_address_pending_authentication.present?
      redirect_to new_session_path, alert: "Enter your email address to sign in."
    end
  end

  def code
    params.expect(:code)
  end

  def authenticate(verification_code)
    if ActiveSupport::SecurityUtils.secure_compare(email_address_pending_authentication || "", verification_code.user.email)
      clear_pending_authentication_token
      start_new_session_for verification_code.user
      redirect_to after_authentication_url
    else
      clear_pending_authentication_token
      redirect_to new_session_path, alert: "Something went wrong. Please try again."
    end
  end

  def rate_limit_exceeded
    redirect_to session_verification_code_path, alert: "Too many attempts. Please try again in 15 minutes."
  end
end
