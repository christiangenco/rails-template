# Phase 7: Profile & Email Change

## Goal

Implement the profile page (edit name, view email) and the secure email change flow (request → verify via emailed link → confirm).

## Steps

### 7.1 ProfilesController

Create `app/controllers/profiles_controller.rb`:

```ruby
class ProfilesController < ApplicationController
  before_action :set_user

  def show
  end

  def update
    if @user.update(user_params)
      redirect_to profile_path, notice: "Your profile has been updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:name)
  end
end
```

### 7.2 Profile View

Create `app/views/profiles/show.html.erb`:

```erb
<div class="mb-8">
  <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">Profile</h1>
</div>

<div class="max-w-2xl">
  <%= tailwind_form_for(@user, url: profile_path, method: :patch) do |f| %>
    <%= f.text_field :name, autocomplete: "name" %>

    <div class="mb-6">
      <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email</label>
      <div class="flex items-center gap-4">
        <span class="text-gray-900 dark:text-gray-100"><%= @user.email %></span>
        <%= link_to "Change email", new_users_email_address_path,
          class: "text-sm text-blue-600 hover:text-blue-500 dark:text-blue-400" %>
      </div>
    </div>

    <%= f.submit "Save Changes", icon: "check" %>
  <% end %>
</div>
```

### 7.3 User::EmailAddressChangeable Concern

Create `app/models/concerns/user/email_address_changeable.rb`:

Uses Rails' `SignedGlobalID` to generate a secure, expiring token that encodes both the user and the new email address.

```ruby
module User::EmailAddressChangeable
  EMAIL_CHANGE_TOKEN_PURPOSE = "change_email_address"
  EMAIL_CHANGE_TOKEN_EXPIRATION = 30.minutes

  extend ActiveSupport::Concern

  included do
    def self.verify_email_change_token(token)
      parsed = SignedGlobalID.parse(token, for: EMAIL_CHANGE_TOKEN_PURPOSE)
      return nil unless parsed

      user = parsed.find
      return nil unless user

      old_email = parsed.params&.fetch("old_email", nil)
      new_email = parsed.params&.fetch("new_email", nil)

      # Verify user's email hasn't changed since token was generated
      return nil if user.email != old_email

      { user: user, old_email: old_email, new_email: new_email }
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  def generate_email_change_token(to:, expires_in: EMAIL_CHANGE_TOKEN_EXPIRATION)
    to_sgid(
      for: EMAIL_CHANGE_TOKEN_PURPOSE,
      expires_in: expires_in,
      old_email: email,
      new_email: to
    ).to_s
  end

  def send_email_change_confirmation(new_email)
    token = generate_email_change_token(to: new_email)
    UserMailer.email_change_confirmation(user: self, new_email: new_email, token: token).deliver_later
  end

  def change_email_address!(new_email)
    old_email = email
    update!(email: new_email)
    UserMailer.email_changed_notification(user: self, old_email: old_email).deliver_later
  end
end
```

Include in User model:
```ruby
include User::EmailAddressChangeable
```

### 7.4 Email Addresses Controller

Create `app/controllers/users/email_addresses_controller.rb`:

```ruby
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
```

### 7.5 Email Address Confirmation Controller

Create `app/controllers/users/email_addresses/confirmations_controller.rb`:

```ruby
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
```

### 7.6 Email Change Views

**`app/views/users/email_addresses/new.html.erb`** — Form with:
- "Change Email Address" heading
- New email input
- "Current email: user@example.com" hint
- "Send confirmation email" button + "Cancel" link

**`app/views/users/email_addresses/create.html.erb`** — Confirmation screen:
- "Check Your Email" heading
- Envelope icon
- "We've sent a confirmation link to **new@email.com**"
- "The link will expire in 30 minutes"
- "Back to profile" link

**`app/views/users/email_addresses/confirmations/show.html.erb`** — Final confirm:
- "Confirm Email Change" heading
- "You're about to change your email to **new@email.com**"
- "Confirm email change" button + "Cancel" link

### 7.7 UserMailer

Create `app/mailers/user_mailer.rb`:

```ruby
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
```

Create corresponding views (HTML + text) for both mailer actions.

### 7.8 Routes

```ruby
resource :profile, only: [:show, :update]

namespace :users do
  resources :email_addresses, only: [:new, :create] do
    resource :confirmation, only: [:show, :create], module: :email_addresses
  end
end
```

## Verification

- Profile page displays current user's name and email
- Can edit name and save
- "Change email" link goes to email change form
- Submitting new email sends confirmation to the NEW email address
- Clicking confirmation link shows final confirm page
- Confirming changes the email
- Old email receives notification that email was changed
- Token expires after 30 minutes
- Can't change to an email that's already taken
- Can't use a token after email has already changed

## Files Created/Modified

- `app/controllers/profiles_controller.rb`
- `app/controllers/users/email_addresses_controller.rb`
- `app/controllers/users/email_addresses/confirmations_controller.rb`
- `app/models/concerns/user/email_address_changeable.rb`
- `app/models/user.rb` (add include)
- `app/mailers/user_mailer.rb`
- `app/views/profiles/show.html.erb`
- `app/views/users/email_addresses/new.html.erb`
- `app/views/users/email_addresses/create.html.erb`
- `app/views/users/email_addresses/confirmations/show.html.erb`
- `app/views/user_mailer/email_change_confirmation.html.erb`
- `app/views/user_mailer/email_change_confirmation.text.erb`
- `app/views/user_mailer/email_changed_notification.html.erb`
- `app/views/user_mailer/email_changed_notification.text.erb`
- `config/routes.rb` (update)
