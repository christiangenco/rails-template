# Rails Template

A batteries-included Rails 8 starter template. SQLite for everything, passwordless email-code auth, team-based multi-tenancy, Alpine.js, Tailwind CSS v4, Kamal deployment with Litestream backups.

## What's Included

- **Rails 8** with all-SQLite architecture (primary, queue, cache, cable)
- **Passwordless authentication** — emailed 6-digit codes, no passwords
- **Team-based multi-tenancy** — personal team auto-created on signup, all records team-scoped
- **Alpine.js + Turbo** — no Stimulus, no React, no build step
- **Tailwind CSS v4** — dark mode toggle (light/dark/auto), Typography & Forms plugins
- **Rich text editing** — Action Text with Trix editor
- **File uploads** — Active Storage with image variants (libvips)
- **Background jobs** — Solid Queue, Solid Cache, Solid Cable (all SQLite)
- **UI component library** — `btn`, `copy_btn`, `pill`, headings, `time_tag_ago`, TailwindFormBuilder, Pagy pagination
- **Modal system** — Alpine.js store-driven, replaces Turbo's `confirm()`
- **Landing page** — full marketing homepage with hero, features, testimonials, FAQ
- **Article system** — file-based static articles with YAML front matter, Tailwind Typography, RSS feed
- **Error pages** — styled 404, 422, 500 pages
- **Admin impersonation** — sign in as any user for debugging
- **Deployment** — Kamal 2 + Litestream continuous SQLite backups to S3

---

## Prerequisites

- **Ruby 3.4.1** (see `.ruby-version`)
- **SQLite 3** with development headers (`libsqlite3-dev` on Ubuntu/Debian)
- **libvips** for image processing (`libvips-dev` on Ubuntu/Debian)
- **Docker** (for deployment only)

---

## Getting Started

### 1. Clone and setup

```bash
git clone https://github.com/cgenco/rails-template.git myapp
cd myapp
bin/setup
```

This installs gems and prepares all four SQLite databases.

### 2. Start the dev server

```bash
bin/dev
```

This runs three processes (defined in `Procfile.dev`):
- **web** — Rails server on `http://localhost:3000`
- **css** — Tailwind CSS watcher (recompiles on file changes)
- **jobs** — Solid Queue worker (processes background jobs)

### 3. Sign in

Visit `http://localhost:3000` and enter any email address. In development, emails open in your browser via [letter_opener](https://github.com/ryanb/letter_opener) — no SMTP config needed. The 6-digit code also appears as a yellow autofill button on the code entry page.

### 4. Seed example data (optional)

```bash
bin/rails db:seed
```

Creates an admin user (`admin@example.com`) with 3 example posts.

---

## Configuration

### Rails Credentials

All secrets live in encrypted credentials. Edit with:

```bash
bin/rails credentials:edit
```

The file structure:

```yaml
# Auto-generated — do not change
secret_key_base: <auto>

# Litestream S3 backup credentials (see Deployment section)
litestream:
  access_key_id: YOUR_S3_ACCESS_KEY
  secret_access_key: YOUR_S3_SECRET_KEY

# Production SMTP (uncomment and configure in config/environments/production.rb)
# smtp:
#   user_name: apikey
#   password: SG.xxxx
#   address: smtp.sendgrid.net
#   port: 587
#   domain: myapp.com
```

### Admin Users

Edit `app/models/user.rb` and update the `admin?` method:

```ruby
def admin?
  email.in?(%w[you@example.com])
end
```

Admins can impersonate users via `POST /impersonate/:id`.

### Production Email (SMTP)

Uncomment and configure SMTP in `config/environments/production.rb`:

```ruby
config.action_mailer.smtp_settings = {
  user_name: Rails.application.credentials.dig(:smtp, :user_name),
  password: Rails.application.credentials.dig(:smtp, :password),
  address: "smtp.sendgrid.net",
  port: 587,
  authentication: :plain,
  domain: "myapp.com",
  enable_starttls_auto: true
}
```

Add the credentials:

```bash
bin/rails credentials:edit
```

```yaml
smtp:
  user_name: apikey
  password: SG.your-sendgrid-api-key
  address: smtp.sendgrid.net
  port: 587
  domain: myapp.com
```

### Production Host

Update `config/environments/production.rb`:

```ruby
config.action_mailer.default_url_options = { host: "myapp.com" }
```

---

## Deployment

This app deploys to a single server with [Kamal 2](https://kamal-deploy.org/). SQLite databases live on a Docker volume and are continuously backed up to S3 via [Litestream](https://litestream.io/).

### 1. Provision a server

Any Linux server with Docker works. Ubuntu 22.04+ on a $6/mo DigitalOcean droplet is fine.

SSH in and ensure Docker is installed:

```bash
curl -fsSL https://get.docker.com | sh
```

### 2. Set up S3-compatible storage for backups

Create a bucket on any S3-compatible service (DigitalOcean Spaces, AWS S3, Backblaze B2, etc.) and generate access keys.

### 3. Configure credentials

```bash
bin/rails credentials:edit
```

```yaml
litestream:
  access_key_id: DO00XXXXXXXXXXXXXXXX
  secret_access_key: your-secret-key-here

# Add SMTP credentials too (see Configuration section above)
```

### 4. Configure deploy.yml

Edit `config/deploy.yml`:

```yaml
service: myapp                    # Your app name
image: myapp                      # Docker image name

servers:
  web:
    - 123.45.67.89                # Your server IP

proxy:
  ssl: true
  host: myapp.com                 # Your domain (DNS must point to server)

registry:
  server: docker.io               # Or ghcr.io, localhost:5555, etc.
  username: yourusername
  password:
    - KAMAL_REGISTRY_PASSWORD
```

Update the Litestream accessory host too:

```yaml
accessories:
  litestream:
    host: 123.45.67.89            # Same server IP
```

### 5. Configure litestream.yml

Edit `config/litestream.yml` — replace the bucket and endpoint:

```yaml
dbs:
  - path: /storage/production.sqlite3
    replicas:
      - type: s3
        bucket: my-backups-bucket
        path: myapp/production.sqlite3
        endpoint: https://nyc3.digitaloceanspaces.com  # Your S3 endpoint
  # ... same for queue, cache, cable databases
```

For AWS S3, remove `endpoint` and add `region: us-east-1`.

### 6. Configure .kamal/secrets

Edit `.kamal/secrets` if you need to add registry credentials:

```bash
RAILS_MASTER_KEY=$(cat config/master.key)
KAMAL_REGISTRY_PASSWORD=your-registry-token
LITESTREAM_ACCESS_KEY_ID=$(bin/rails r "puts Rails.application.credentials.dig(:litestream, :access_key_id)")
LITESTREAM_SECRET_ACCESS_KEY=$(bin/rails r "puts Rails.application.credentials.dig(:litestream, :secret_access_key)")
```

### 7. Deploy

First time:

```bash
kamal setup
```

Subsequent deploys:

```bash
kamal deploy
```

### Useful Kamal commands

```bash
kamal console              # Rails console on server
kamal logs                 # Tail application logs
kamal shell                # SSH into the container
kamal dbc                  # Database console (SQLite)
kamal app logs             # Application-only logs
kamal accessory logs litestream  # Backup logs
```

### Restoring from backup

If you need to restore from a Litestream backup:

```bash
# Install litestream locally: https://litestream.io/install/

export LITESTREAM_ACCESS_KEY_ID=your_key
export LITESTREAM_SECRET_ACCESS_KEY=your_secret

# Restore each database
litestream restore -o production.sqlite3 \
  s3://my-backups-bucket/myapp/production.sqlite3 \
  -endpoint https://nyc3.digitaloceanspaces.com

# Copy to server
scp production.sqlite3 root@YOUR_SERVER_IP:/var/lib/docker/volumes/myapp_storage/_data/

# Restart
kamal app restart
```

---

## Development

### Adding a new team-scoped resource

```bash
bin/rails generate model Widget name:string team:references created_by:references
```

Edit migration so `created_by` references `users`:

```ruby
t.references :created_by, foreign_key: { to_table: :users }, null: true
```

Model:

```ruby
class Widget < ApplicationRecord
  belongs_to :team
  belongs_to :created_by, class_name: "User", optional: true
  validates :name, presence: true
  scope :newest_first, -> { order(created_at: :desc) }
end
```

Add to `app/models/team.rb`:

```ruby
has_many :widgets, dependent: :destroy
```

Controller:

```ruby
class WidgetsController < ApplicationController
  include TeamScoped
  before_action :set_widget, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @widgets = pagy(Current.team.widgets.newest_first)
  end

  # ... standard CRUD actions, always scope to Current.team
  private

  def set_widget
    @widget = Current.team.widgets.find(params[:id])
  end
end
```

Routes (inside the team scope in `config/routes.rb`):

```ruby
scope "/teams/:team_id", constraints: { team_id: /\d+/ } do
  resources :widgets
  # ... existing routes
end
```

See `app/controllers/posts_controller.rb` for a complete reference implementation.

### Adding a JavaScript package

```bash
bin/importmap pin <package-name>
```

Then import in `app/javascript/application.js`.

### Adding an article

Create `app/views/articles/content/my-article.html.erb`:

```erb
---
title: "My Article Title"
description: "A brief description for SEO and article listings."
author: "Your Name"
published_at: 2026-02-15
---

<p>Article content here. Standard HTML, styled by Tailwind Typography.</p>
<h2>Subheading</h2>
<p>More content...</p>
```

It will automatically appear at `/a/my-article` and in the article index at `/a`.

### Mailer previews

Visit `http://localhost:3000/rails/mailers` to preview all email templates.

### Testing error pages

In development:
- `http://localhost:3000/dev/errors/404`
- `http://localhost:3000/dev/errors/500`

---

## Architecture

See [AGENTS.md](./AGENTS.md) for AI-friendly architecture documentation, patterns, and conventions.

| Component | Technology |
|-----------|-----------|
| Database | SQLite (4 databases: primary, queue, cache, cable) |
| Frontend | Alpine.js + Turbo (importmaps, no Node.js) |
| CSS | Tailwind CSS v4 (tailwindcss-rails gem) |
| Auth | Passwordless 6-digit email codes |
| Multi-tenancy | Team-based (every user gets a personal team) |
| Background jobs | Solid Queue |
| Caching | Solid Cache |
| WebSockets | Solid Cable |
| File uploads | Active Storage (local disk) |
| Rich text | Action Text + Trix |
| Pagination | Pagy |
| Icons | Heroicons via rails_icons |
| Deployment | Kamal 2 |
| DB backups | Litestream → S3 |

---

## License

MIT
