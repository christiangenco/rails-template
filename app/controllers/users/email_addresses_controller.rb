class Users::EmailAddressesController < ApplicationController
  def new
    @email_address = ""
  end

  def create
    @email_address = params[:email_address].to_s.strip.downcase

    if !valid_email?(@email_address)
      flash.now[:alert] = "Please enter a valid email address."
      render :new, status: :unprocessable_entity
      return
    end

    if @email_address == current_user.email
      flash.now[:alert] = "That's already your current email address."
      render :new, status: :unprocessable_entity
      return
    end

    if User.exists?(email: @email_address)
      flash.now[:alert] = "This email address is already in use."
      render :new, status: :unprocessable_entity
      return
    end

    current_user.send_email_change_confirmation(@email_address)
    render :create
  end

  private

  def valid_email?(email)
    email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
