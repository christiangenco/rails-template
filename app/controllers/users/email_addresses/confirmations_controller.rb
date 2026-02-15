class Users::EmailAddresses::ConfirmationsController < ApplicationController
  before_action :verify_token

  def show
  end

  def create
    result = User.verify_email_change_token(@token)

    if result && result[:user] == current_user
      current_user.change_email_address!(result[:new_email])
      redirect_to profile_path, notice: "Your email has been updated to #{result[:new_email]}."
    else
      redirect_to profile_path, alert: "This link is invalid or has expired."
    end
  end

  private

  def verify_token
    @token = params[:email_address_id]
    result = User.verify_email_change_token(@token)

    if result.nil? || result[:user] != current_user
      redirect_to profile_path, alert: "This link is invalid or has expired."
    else
      @new_email = result[:new_email]
    end
  end
end
