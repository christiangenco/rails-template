class SessionsController < ApplicationController
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded

  layout "public"

  def new
  end

  def create
    if user = User.find_by(email: email_address)
      if user.active_for_passwordless_authentication?
        redirect_to_session_magic_link user.send_magic_link
      else
        redirect_to new_session_path, alert: user.inactive_message
      end
    elsif signups_enabled?
      user = User.create!(email: email_address)
      redirect_to_session_magic_link user.send_magic_link(purpose: :sign_up)
    else
      redirect_to_fake_session_magic_link(email_address)
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "You have been signed out."
  end

  private

  def email_address
    params[:email_address]&.strip&.downcase
  end

  def signups_enabled?
    true
  end

  def rate_limit_exceeded
    redirect_to new_session_path, alert: "Too many requests. Please try again later."
  end
end
