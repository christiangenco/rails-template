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
- **Auth**: Passwordless email codes (VerificationCode model)
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

## New Project Setup

```bash
bin/setup-new-project --name myapp --domain myapp.com --server-ip 123.45.67.89 \
  --smtp-user myapp@genco.email --smtp-password "YOUR_SMTP_PASSWORD" \
  --mail-from "My App <myapp@genco.email>"
```

Regenerates `config/master.key`, generates `secret_key_base` and `active_record_encryption` keys, carries forward shared secrets (GHCR token, Litestream keys), configures Mailgun SMTP, and replaces all placeholders. Run with `--help` for all options.

### Email Setup (Mailgun via genco.email)

All apps send email through Mailgun using the `genco.email` domain. For each new app:

1. **Create SMTP credentials on Mailgun** for `myapp@genco.email`:
   ```bash
   curl -s --user "api:YOUR_MAILGUN_API_KEY" \
     "https://api.mailgun.net/v3/domains/genco.email/credentials" \
     -d "login=myapp@genco.email" \
     -d "password=SomeSecurePassword123!"
   ```
   The Mailgun API key can be retrieved from the running `mailgun-mailboxes` app:
   ```bash
   ssh apps "docker exec \$(docker ps -q --filter name=mailgun-mailboxes-web) bin/rails runner \"puts User.first.mailgun_api_key\""
   ```

2. **Pass the SMTP credentials** to `bin/setup-new-project` via `--smtp-user` and `--smtp-password`.

3. If you forgot to pass them during setup, manually:
   - Add `mailgun.smtp_password` to Rails credentials (`bin/rails credentials:edit`)
   - Configure `config/environments/production.rb` with `smtp.mailgun.org`, port 587, and `user_name: "myapp@genco.email"`
   - Update `app/mailers/application_mailer.rb` default from address

**⚠️ Common gotcha:** The SMTP `user_name` must match the Mailgun credential you created — NOT `postmaster@genco.email`. If login emails fail with `Net::SMTPAuthenticationError (535 Authentication failed)`, this is almost certainly the issue.

## Deployment

- **Registry**: GHCR (ghcr.io) — token stored in Rails credentials at `ghcr.token`
- **Builder**: Local build with `context: .` (not a git clone)
- **Tailwind v4 workaround**: Tailwind v4's Rust-based oxide scanner produces incomplete CSS inside Docker's overlayfs. Three-part fix:
  1. `.kamal/hooks/pre-build` builds Tailwind on the host before Docker build
  2. `builder.context: .` in `deploy.yml` preserves the pre-built CSS in the Docker context
  3. `SKIP_TAILWIND_BUILD=1` in the Dockerfile + `lib/tasks/skip_tailwind.rake` skips the Tailwind step during `assets:precompile`
- **GitHub Secrets** (for CI deploys): `SSH_PRIVATE_KEY`, `RAILS_MASTER_KEY`
- **Backups**: Litestream sidecar for continuous SQLite replication to S3

## Development Server

Each project has a unique port (stored in `.dev-port` and registered in `~/projects/.ports`). The server binds to `0.0.0.0` so it's accessible from other devices on the local network.

**Conventions:**
- **Port**: Read from `.dev-port` file in project root (or `~/projects/.ports`)
- **tmux session name**: `{project}-dev` (e.g., `book-dev`, `chat-dev`)
- **Local URL**: `http://{project}.localhost:{port}` (e.g., `http://book.localhost:3105`)
- **Binding**: `0.0.0.0` (set in `config/puma.rb`, accessible from phone/other devices)

**To start/open a project:**
```bash
dev-server book            # Start tmux session + open browser
dev-server book --start-only   # Just start the server in tmux
dev-server book --open-only    # Just open the URL in browser
```

**Manual start:**
```bash
tmux new-session -d -s book-dev -c ~/projects/book "PORT=3105 bin/dev"
open http://book.localhost:3105
```

**When setting up a new project**, assign the next available port in `~/projects/.ports` and create a `.dev-port` file:
```bash
echo "myapp:3121" >> ~/projects/.ports
echo "3121" > ~/projects/myapp/.dev-port
```
