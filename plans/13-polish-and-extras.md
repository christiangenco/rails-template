# Phase 13: Polish & Extras

## Goal

Final polish: error pages, admin impersonation, health check, letter_opener for dev emails, and the project's AGENTS.md documentation.

## Steps

### 13.1 Styled Error Pages

Create custom error pages that match the app's design:

#### 404 Not Found

Create `app/views/errors/not_found.html.erb`:

```erb
<div class="text-center py-24">
  <p class="text-base font-semibold text-blue-600 dark:text-blue-400">404</p>
  <h1 class="mt-4 text-4xl font-semibold tracking-tight text-gray-900 dark:text-gray-100 sm:text-5xl">
    Page not found
  </h1>
  <p class="mt-6 text-base/7 text-gray-600 dark:text-gray-300">
    Sorry, we couldn't find the page you're looking for.
  </p>
  <div class="mt-10">
    <%= btn "Go back home", href: root_path, icon: "arrow-left" %>
  </div>
</div>
```

#### 500 Internal Server Error

Create `app/views/errors/internal_error.html.erb`:

```erb
<div class="text-center py-24">
  <p class="text-base font-semibold text-red-600 dark:text-red-400">500</p>
  <h1 class="mt-4 text-4xl font-semibold tracking-tight text-gray-900 dark:text-gray-100 sm:text-5xl">
    Something went wrong
  </h1>
  <p class="mt-6 text-base/7 text-gray-600 dark:text-gray-300">
    We're looking into it. Please try again in a moment.
  </p>
  <div class="mt-10">
    <%= btn "Go back home", href: root_path, icon: "arrow-left" %>
  </div>
</div>
```

#### 422 Unprocessable Entity

Similar pattern with "Unprocessable request" message.

Add to ApplicationController:
```ruby
rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

private

def render_not_found
  render "errors/not_found", status: :not_found, layout: "application"
end
```

For 500 errors in production, configure `config/environments/production.rb`:
```ruby
config.exceptions_app = routes
```

And add routes:
```ruby
match "/404", to: "errors#not_found", via: :all
match "/422", to: "errors#unprocessable", via: :all
match "/500", to: "errors#internal_error", via: :all
```

Create `app/controllers/errors_controller.rb`:
```ruby
class ErrorsController < ApplicationController
  allow_unauthenticated_access

  def not_found
    render status: :not_found
  end

  def unprocessable
    render status: :unprocessable_entity
  end

  def internal_error
    render status: :internal_server_error
  end
end
```

### 13.2 Admin Impersonation

Add to ApplicationController:

```ruby
helper_method :true_user, :admin_impersonating?

private

def true_user
  @true_user ||= User.find_by(id: session[:true_user_id]) || current_user
end

def admin_impersonating?
  current_user && true_user != current_user
end

def current_user
  if session[:impersonated_user_id]
    @current_user ||= User.find_by(id: session[:impersonated_user_id])
  else
    Current.user
  end
end

def ensure_admin
  unless true_user&.admin?
    redirect_to root_path, alert: "Not authorized."
  end
end
```

Add an impersonation banner to `application.html.erb`:

```erb
<% if admin_impersonating? %>
  <div class="bg-yellow-100 dark:bg-yellow-900/30 border-b border-yellow-200 dark:border-yellow-800 px-4 py-2 text-center text-sm text-yellow-800 dark:text-yellow-200">
    Impersonating <strong><%= current_user.email %></strong>
    <%= link_to "Stop", stop_impersonating_path, data: { turbo_method: :post },
      class: "ml-2 font-semibold underline" %>
  </div>
<% end %>
```

Impersonation routes (only usable by admins):
```ruby
post "impersonate/:id", to: "admin#impersonate", as: :impersonate
post "stop_impersonating", to: "admin#stop_impersonating", as: :stop_impersonating
```

Simple AdminController:
```ruby
class AdminController < ApplicationController
  before_action :ensure_admin

  def impersonate
    user = User.find(params[:id])
    session[:true_user_id] = true_user.id
    session[:impersonated_user_id] = user.id
    redirect_to root_path, notice: "Now impersonating #{user.email}"
  end

  def stop_impersonating
    session.delete(:impersonated_user_id)
    session.delete(:true_user_id)
    redirect_to root_path, notice: "Stopped impersonating"
  end
end
```

### 13.3 Health Check

Already included by Rails 8 default:

```ruby
get "up" => "rails/health#show", as: :rails_health_check
```

Verify it returns 200 at `/up`.

### 13.4 Development Email Setup

Ensure `letter_opener` is configured in `config/environments/development.rb`:

```ruby
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

This opens sent emails in the browser during development — no SMTP config needed.

### 13.5 Mailer Preview Support

Create `test/mailers/previews/magic_link_mailer_preview.rb`:

```ruby
class MagicLinkMailerPreview < ActionMailer::Preview
  def sign_in_instructions
    user = User.first || User.new(email: "test@example.com")
    magic_link = MagicLink.new(user: user, code: "ABC123", expires_at: 15.minutes.from_now)
    MagicLinkMailer.sign_in_instructions(magic_link)
  end
end
```

Accessible at `/rails/mailers/magic_link_mailer/sign_in_instructions` in development.

### 13.6 Seeds File

Create `db/seeds.rb`:

```ruby
if Rails.env.development?
  puts "Seeding development data..."

  # Create admin user
  admin = User.find_or_create_by!(email: "admin@example.com") do |u|
    u.name = "Admin User"
  end

  # Create a few example posts
  team = admin.default_team
  3.times do |i|
    team.posts.find_or_create_by!(title: "Example Post #{i + 1}") do |post|
      post.created_by = admin
      post.body = "<p>This is example post #{i + 1}. It was seeded for development.</p>"
    end
  end

  puts "Done! Admin user: admin@example.com"
end
```

### 13.7 Dev Error Pages (development only)

Create `app/controllers/dev_errors_controller.rb` for testing error pages:

```ruby
class DevErrorsController < ApplicationController
  allow_unauthenticated_access

  def not_found
    raise ActiveRecord::RecordNotFound
  end

  def internal_error
    raise "Test 500 error"
  end
end
```

Routes (development only):
```ruby
if Rails.env.development?
  get "dev/errors/404", to: "dev_errors#not_found"
  get "dev/errors/500", to: "dev_errors#internal_error"
end
```

### 13.8 AGENTS.md

Create `AGENTS.md` at the project root with development guidelines:

```markdown
# AGENTS.md

This app is a Ruby on Rails 8 application template using SQLite, Alpine.js, Tailwind CSS, and Kamal.

## Development Guidelines

- Follow TDD: write a failing test first, then write code to make it pass.
- Controllers must use only standard REST actions.
- Push business logic to models and concerns.
- Do NOT run `bin/rails assets:precompile` in development. Assets are compiled on-the-fly.
- Use `bin/importmap pin <package>` to add JS packages (not npm install).
- Use `rails g` commands for generating models, controllers, and migrations.
- Use `bin/rails runner` instead of the Rails console for one-off scripts.

## Architecture

- **Database**: SQLite for everything (primary, queue, cache, cable)
- **Frontend**: Alpine.js + Turbo (no Stimulus), Tailwind CSS v4
- **Auth**: Passwordless email codes (MagicLink model)
- **Multi-tenancy**: Team-based. All app records belong to a team.
- **Jobs**: Solid Queue (SQLite-backed)
- **Cache**: Solid Cache (SQLite-backed)
- **Deployment**: Kamal 2 + Litestream SQLite backups

## Key Patterns

### Adding a new team-scoped resource

1. Generate model with `team:references`
2. Add `belongs_to :team` and `has_many :resources` to Team
3. Controller: `include TeamScoped`, scope all queries to `Current.team`
4. Routes: inside `scope "/teams/:team_id"` block
5. Views: pass `team_id: Current.team.id` to all path helpers

### Authentication

- `require_authentication` is the default (set in ApplicationController)
- Use `allow_unauthenticated_access` for public pages
- Use `require_unauthenticated_access` for login/signup pages
- Access current user via `current_user` or `Current.user`
- Access current team via `Current.team`

### UI Helpers

- `btn "Text", variant: :primary, icon: "plus"` — styled button
- `copy_btn "value"` — copy to clipboard with feedback
- `pill "Badge", variant: :success` — badge/pill
- `h1 "Title"` through `h6` — styled headings
- `time_tag_ago(datetime)` — "2 hours ago" with full date tooltip
- `tailwind_form_for(@model)` — form builder with Tailwind styling

## Development Server

```bash
bin/dev  # Starts web server, Tailwind watcher, and job worker
```
```

### 13.9 README.md

Create a `README.md` with:
- Project description
- Prerequisites (Ruby 3.4.1, SQLite)
- Setup instructions (`bin/setup`, `bin/dev`)
- Deployment instructions (Kamal)
- Link to AGENTS.md for architecture details

### 13.10 bin/setup

Create/update `bin/setup`:

```bash
#!/usr/bin/env bash
set -e

echo "Installing dependencies..."
bundle install

echo "Preparing databases..."
bin/rails db:prepare

echo "Done! Run bin/dev to start the development server."
```

## Verification

- `/dev/errors/404` renders styled 404 page (development)
- `/dev/errors/500` renders styled 500 page (development)
- `/up` returns 200 (health check)
- `letter_opener` opens emails in browser
- Mailer previews work at `/rails/mailers`
- `bin/rails db:seed` creates admin user and example posts
- Admin impersonation works (set admin email in User model, visit impersonate route)
- `bin/setup` runs cleanly on a fresh checkout
- AGENTS.md documents all key patterns and conventions

## Files Created/Modified

- `app/controllers/errors_controller.rb`
- `app/controllers/admin_controller.rb`
- `app/controllers/dev_errors_controller.rb`
- `app/views/errors/not_found.html.erb`
- `app/views/errors/internal_error.html.erb`
- `app/views/errors/unprocessable.html.erb`
- `app/views/layouts/application.html.erb` (add impersonation banner)
- `app/controllers/application_controller.rb` (add impersonation, error handling)
- `config/routes.rb` (add error routes, impersonation, health check)
- `config/environments/development.rb` (letter_opener)
- `test/mailers/previews/magic_link_mailer_preview.rb`
- `db/seeds.rb`
- `bin/setup`
- `AGENTS.md`
- `README.md`
