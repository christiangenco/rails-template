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
