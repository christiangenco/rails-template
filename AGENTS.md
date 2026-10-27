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

### Email Setup (Mailgun via gxb.vc)

All apps send email through Mailgun using the `gxb.vc` domain (default SMTP user
`NAME@gxb.vc`, default from address `noreply@gxb.vc`, matching what the sites
platform does). `bin/setup-new-project` refuses to finish without
`--smtp-password` (or a `MAILGUN_SMTP_PASSWORD` env var) unless you pass
`--no-mail` explicitly. With `--no-mail`, the app boots fine but any mailer
raises a clear error ("Mail is not configured for this app...") the first time
it's used, instead of failing SMTP auth silently against a placeholder
password — this is what happened to the sites app for five days in September
2026 (see `plans/reviews/30/andyform-report.md` in the sites repo). In
production, a credential that goes missing after setup (a bad deploy, a wrong
master key) raises at boot with one sentence naming the credentials key and
the setup flag, instead of starting with a nil password.

1. **Let the setup script make the SMTP login.** Pass `--create-smtp` to `bin/setup-new-project`. It makes a
   random 32-character password, creates the Mailgun SMTP login `NAME@gxb.vc` with it, and stores it only in the
   new app's credentials. It never prints the password. The Mailgun API key is read from a file
   (`MAILGUN_API_KEY_FILE`, default `~/tools/mailgun-cli/.env`).
   - Never type or copy an example password. In October 2026 an app ran for months with the example password
     from this file, and the example was in every agent log.
   - Never print the Mailgun API key (no `puts ...mailgun_api_key`, no `credentials:show`). To check a key, use
     `bin/cred-check APP NAME` in `~/projects/hq` (presence, length and a short hash only).

2. If you already made a login by hand, pass its password with `--smtp-password-file PATH` (a mode-600 file)
   instead of on the command line. `--smtp-user` and `--mail-from` default from `--name`.

3. If you forgot to pass them during setup, manually:
   - Add `mailgun.smtp_password` to Rails credentials (`bin/rails credentials:edit`)
   - Configure `config/environments/production.rb` to require `require_relative "../../app/lib/mailgun_smtp_settings"`
     and set `config.action_mailer.smtp_settings = MailgunSmtpSettings.for(user_name: "myapp@gxb.vc")`
   - Update `app/mailers/application_mailer.rb` default from address

4. **Verify a send after every deploy that touches mail**: `bundle exec kamal app exec --reuse "bin/mail-check"`
   sends one message through `ApplicationMailer` to `christian@gxb.vc` (or `MAIL_CHECK_TO`/an argument),
   prints the SMTP settings in use with the password redacted, and prints the resulting Message-ID
   (searchable in the Mailgun logs) — or exits non-zero with the delivery error.

**⚠️ Common gotcha:** The SMTP `user_name` must match the Mailgun credential you created — NOT `postmaster@gxb.vc`. If login emails fail with `Net::SMTPAuthenticationError (535 Authentication failed)`, this is almost certainly the issue.

## GXB Chat Widget Integration

GXB apps that embed the chat.gxb.vc widget need to provision `ProjectMembership` records on chat.gxb.vc at login time, or users will see "Access Denied" in the sidebar. See digi and trigate for working examples.

### Setup checklist

1. **Register a Project on chat.gxb.vc** with a matching `api_key` (store as `chat_api_key` or `chat_api.key` in the host app's Rails credentials).
2. **Add the widget script** to the layout:
   ```erb
   <script src="https://chat.gxb.vc/widget.js" data-project="myapp"></script>
   ```
3. **Add `ChatMembershipProvisioner` concern** — calls `POST https://chat.gxb.vc/api/memberships` with the user's `auth_uid` and `email`:
   ```ruby
   # app/controllers/concerns/chat_membership_provisioner.rb
   module ChatMembershipProvisioner
     extend ActiveSupport::Concern

     private

     def provision_chat_membership(user)
       api_key = Rails.application.credentials.chat_api_key # or dig(:chat_api, :key)
       return unless api_key.present?

       uri = URI("https://chat.gxb.vc/api/memberships")
       req = Net::HTTP::Post.new(uri)
       req["X-Api-Key"] = api_key
       req["Content-Type"] = "application/json"
       req.body = { auth_uid: user.auth_uid, email: user.email }.to_json

       Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 3) do |http|
         http.request(req)
       end
     rescue StandardError => e
       Rails.logger.warn "Failed to provision chat membership for #{user.email}: #{e.message}"
     end
   end
   ```
4. **Call `provision_chat_membership(user)`** in `AuthCallbacksController#create` right after `start_new_session_for(user)`.
5. **Expose chat API endpoints** if the chat server needs to query back into the host app's database:
   - `app/controllers/concerns/chat_api_authenticatable.rb` — validates `Authorization: Bearer <api_key>` + `X-Auth-UID`/`X-Auth-Email` headers, with email fallback + `auth_uid` backfill for pre-SSO users.
   - `POST /chat_api/query` — execute read-only SQL, return paginated results.
   - `POST /chat_api/execute_tool` — execute named tools (describe_table, column_stats, etc.).

### How it works

The chat.gxb.vc memberships API (`POST /api/memberships`) accepts `auth_uid` and `email`. It finds or creates a User stub on chat.gxb.vc and creates a `ProjectMembership`. The call is fire-and-forget with a 3-second timeout — if it fails, users can still use the host app; they just won't have chat access until their next login.

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
