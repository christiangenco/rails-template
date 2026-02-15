# Phase 5: Authentication

## Goal

Implement passwordless authentication via emailed 6-digit codes. No passwords, no magic links — just enter email, receive code, enter code, you're in. Supports both sign-in (existing users) and sign-up (new users).

## Steps

### 5.1 Generate Models

#### User

```bash
bin/rails generate model User \
  email:string:uniq \
  name:string \
  sign_in_count:integer \
  current_sign_in_at:datetime \
  current_sign_in_ip:string \
  last_sign_in_at:datetime \
  last_sign_in_ip:string \
  deleted_at:datetime \
  deactivated_at:datetime
```

Edit migration to add defaults:
```ruby
t.integer :sign_in_count, default: 0, null: false
```

Add index on `deleted_at` for scoping active users.

#### Session

```bash
bin/rails generate model Session \
  user:references \
  user_agent:string \
  ip_address:string
```

#### MagicLink

```bash
bin/rails generate model MagicLink \
  user:references \
  code:string:uniq \
  purpose:integer \
  expires_at:datetime
```

Run `bin/rails db:migrate`.

### 5.2 User Model

```ruby
class User < ApplicationRecord
  include User::Deactivatable

  has_many :magic_links, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships
  has_many :owned_teams, class_name: "Team", foreign_key: :owner_id, dependent: :nullify

  normalizes :email, with: ->(v) { v.strip.downcase.presence }

  after_create :ensure_default_team

  def ensure_default_team
    return if teams.any?
    Team.create_with_owner(
      team_attrs: { name: "#{email}'s Workspace" },
      owner: self
    )
  end

  def admin?
    # TODO: Replace with your admin email(s)
    false
  end

  def personal_team
    owned_teams.find_by(kind: :personal) || owned_teams.first || teams.first
  end

  def default_team
    teams.joins(:memberships).where(memberships: { status: :active }).order(:created_at).first
  end

  def display_id
    name.present? ? name : email
  end

  def send_magic_link(purpose: :sign_in)
    magic_links.create!(purpose: purpose).tap do |ml|
      MagicLinkMailer.sign_in_instructions(ml).deliver_later
    end
  end

  def active_for_passwordless_authentication?
    deleted_at.nil? && deactivated_at.nil?
  end

  def inactive_message
    if deactivated_at.present?
      "This account has been deactivated."
    elsif deleted_at.present?
      "This account has been deleted."
    else
      "This account is not active."
    end
  end
end
```

Note: `ensure_default_team` references the Team model from Phase 6. During Phase 5 testing, we can stub this or create the Team model as a skeleton.

### 5.3 User::Deactivatable Concern

Create `app/models/concerns/user/deactivatable.rb`:

```ruby
module User::Deactivatable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deactivated_at: nil) }
    scope :deactivated, -> { where.not(deactivated_at: nil) }
  end

  def deactivate!
    transaction do
      update!(deactivated_at: Time.current)
      memberships.update_all(status: :disabled)
      sessions.destroy_all
    end
  end

  def deactivated?
    deactivated_at.present?
  end

  def active?
    !deactivated?
  end

  def reactivate!
    update!(deactivated_at: nil)
  end
end
```

### 5.4 Session Model

```ruby
class Session < ApplicationRecord
  belongs_to :user
end
```

### 5.5 MagicLink Model

```ruby
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  belongs_to :user

  enum :purpose, %w[sign_in sign_up], prefix: :for, default: :sign_in

  scope :active, -> { where(expires_at: Time.current...) }
  scope :stale, -> { where(expires_at: ...Time.current) }

  before_validation :generate_code, on: :create
  before_validation :set_expiration, on: :create

  validates :code, uniqueness: true, presence: true

  class << self
    def consume(code)
      active.find_by(code: Code.sanitize(code))&.consume
    end

    def cleanup
      stale.delete_all
    end
  end

  def consume
    destroy
    self
  end

  private

  def generate_code
    self.code ||= loop do
      candidate = Code.generate(CODE_LENGTH)
      break candidate unless self.class.exists?(code: candidate)
    end
  end

  def set_expiration
    self.expires_at ||= EXPIRATION_TIME.from_now
  end
end
```

### 5.6 MagicLink::Code Module

Create `app/models/magic_link/code.rb`:

```ruby
module MagicLink::Code
  # Uppercase letters and digits, excluding confusable characters (O, I, L)
  ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze
  CODE_SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze

  class << self
    def generate(length)
      SecureRandom.alphanumeric(length, chars: ALPHABET)
    end

    def sanitize(code)
      return nil if code.blank?
      code.to_s.upcase
        .then { |c| CODE_SUBSTITUTIONS.reduce(c) { |r, (from, to)| r.gsub(from, to) } }
        .then { |c| c.gsub(/[^#{ALPHABET.join}]/, "") }
    end
  end
end
```

### 5.7 Current Model

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :team, :session

  def session=(value)
    super(value)
    self.user = session&.user
  end
end
```

### 5.8 Authentication Concern

Create `app/controllers/concerns/authentication.rb` — ported from Fileinbox.

Key features:
- `require_authentication` before_action (default for all controllers)
- `allow_unauthenticated_access` class method to skip auth
- `require_unauthenticated_access` class method to redirect logged-in users away
- Session management via signed cookie (`:session_id`)
- `start_new_session_for(user)` — creates Session record, sets cookie, tracks sign-in
- `terminate_session` — destroys Session, deletes cookie
- `request_authentication` — stores `return_to_after_authenticating` in session, redirects to login
  - **Passes `email=` query param** through to the login form if present on the original request
- `after_authentication_url` — returns the stored URL or `default_authenticated_path`
- Pending authentication token via `Rails.application.message_verifier(:pending_authentication)` — stores email in a signed cookie during the code entry flow
- `redirect_to_session_magic_link` — sets pending auth token cookie, redirects to code entry page
- `redirect_to_fake_session_magic_link` — for non-existent users (timing attack prevention)
- Development helper: flashes the magic link code and sets `X-Magic-Link-Code` header

### 5.9 SessionsController

Create `app/controllers/sessions_controller.rb`:

```ruby
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
```

### 5.10 Sessions::MagicLinksController

Create `app/controllers/sessions/magic_links_controller.rb`:

```ruby
class Sessions::MagicLinksController < ApplicationController
  require_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: :rate_limit_exceeded
  before_action :ensure_that_email_address_pending_authentication_exists

  layout "public"

  def show
  end

  def create
    if magic_link = MagicLink.consume(code)
      authenticate(magic_link)
    else
      redirect_to session_magic_link_path, flash: { shake: true }
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

  def authenticate(magic_link)
    if ActiveSupport::SecurityUtils.secure_compare(email_address_pending_authentication || "", magic_link.user.email)
      clear_pending_authentication_token
      start_new_session_for magic_link.user
      redirect_to after_authentication_url
    else
      clear_pending_authentication_token
      redirect_to new_session_path, alert: "Something went wrong. Please try again."
    end
  end

  def rate_limit_exceeded
    redirect_to session_magic_link_path, alert: "Too many attempts. Please try again in 15 minutes."
  end
end
```

### 5.11 MagicLinkMailer

Create `app/mailers/magic_link_mailer.rb`:

```ruby
class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    @user = magic_link.user

    mail(to: @user.email, subject: "Your sign-in code is #{magic_link.code}")
  end
end
```

Create `app/views/magic_link_mailer/sign_in_instructions.html.erb`:

Simple email showing the 6-digit code in a large monospaced font with a grey background box. Says "This code expires in 15 minutes."

Create `app/views/magic_link_mailer/sign_in_instructions.text.erb`:

Plain text version.

### 5.12 Login View (sessions/new.html.erb)

Uses the `public` layout. Shows:
- "Sign in to your account" heading
- "Enter your email and we'll send you a code to sign in." subtitle
- Email input pre-filled from `params[:email]`
- "Continue" submit button

### 5.13 Code Entry View (sessions/magic_links/show.html.erb)

Uses the `public` layout. Shows:
- "Check your email" heading
- "We sent a code to **user@email.com**" subtitle
- Large monospaced code input (6 chars, centered, letter-spacing)
- Auto-submits when 6 characters entered (Alpine `@input`)
- Paste support (auto-submit after paste)
- Auto-uppercases input, strips non-alphanumeric
- Shake animation on invalid code (`flash[:shake]`)
- "Didn't get the email? Try again" link
- Development-only autofill button that auto-fills and submits the code
- Attributes to disable password manager interference: `data-1p-ignore`, `data-lpignore`, `data-bwignore`, `data-protonpass-ignore`

### 5.14 Routes

```ruby
resource :session, only: [:new, :create, :destroy] do
  scope module: :sessions do
    resource :magic_link, only: [:show, :create]
  end
end

# Redirect old paths
get "/users/sign_in", to: redirect("/session/new")
get "/users/sign_up", to: redirect("/session/new")
```

### 5.15 ApplicationController

Create `app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Authentication

  helper_method :current_user

  before_action :set_current_team

  private

  def current_user
    Current.user
  end

  def set_current_team
    return unless params[:team_id].present?
    team = Team.find_by(id: params[:team_id])
    Current.team = team if team
  end
end
```

### 5.16 Email Layout

Create `app/views/layouts/email_layout.html.erb` — a simple responsive email layout:
- White card on grey background
- Sans-serif font stack
- Mobile-friendly (600px max-width)
- Preheader text support via `@summary`
- Footer with app name

## Verification

- Visit `/session/new` — see login form
- Enter an email — code is sent (check `letter_opener` in development)
- In dev, the code appears on the code entry page as a yellow autofill button
- Enter correct code — redirected to dashboard
- Enter wrong code — shake animation, stay on code entry page
- Visit a protected page while logged out — redirect to login, then redirect back after auth
- Visit a protected page with `?email=test@example.com` — email is pre-filled on login form
- Rate limiting works (10 attempts per 3 min on create, 10 per 15 min on magic link verify)
- Sign out works

## Files Created/Modified

- `app/models/user.rb`
- `app/models/session.rb`
- `app/models/magic_link.rb`
- `app/models/magic_link/code.rb`
- `app/models/current.rb`
- `app/models/concerns/user/deactivatable.rb`
- `app/controllers/concerns/authentication.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/sessions/magic_links_controller.rb`
- `app/mailers/application_mailer.rb`
- `app/mailers/magic_link_mailer.rb`
- `app/views/sessions/new.html.erb`
- `app/views/sessions/magic_links/show.html.erb`
- `app/views/magic_link_mailer/sign_in_instructions.html.erb`
- `app/views/magic_link_mailer/sign_in_instructions.text.erb`
- `app/views/layouts/email_layout.html.erb`
- `config/routes.rb`
- `db/migrate/*_create_users.rb`
- `db/migrate/*_create_sessions.rb`
- `db/migrate/*_create_magic_links.rb`
