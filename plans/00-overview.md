# Rails Template — Master Plan

A reusable Rails 8 starter template extracted from Fileinbox. SQLite for everything, Alpine.js (not Stimulus), Tailwind CSS v4, Kamal deployment with Litestream backups, email-code authentication, team-based multi-tenancy, and a rich set of UI helpers.

## Phases

| # | Phase | Description |
|---|-------|-------------|
| 01 | [Scaffold & Databases](./01-scaffold-and-databases.md) | Generate Rails app, configure SQLite multi-db, add gems |
| 02 | [Tailwind CSS](./02-tailwind-css.md) | Tailwind v4 with dark mode, typography, forms plugins |
| 03 | [Alpine.js + Turbo](./03-alpine-and-turbo.md) | Alpine.js with turbo adapter, modal system, confirm override |
| 04 | [UI Helpers & Layouts](./04-ui-helpers-and-layouts.md) | btn, copy_btn, pill, headings, time_tag_ago, form builder, Pagy, layouts |
| 05 | [Authentication](./05-authentication.md) | Email-code login (MagicLink), sessions, rate limiting |
| 06 | [Teams & Memberships](./06-teams-and-memberships.md) | Team model, memberships, roles, auto-create, team-scoped controllers |
| 07 | [Profile & Email Change](./07-profile-and-email-change.md) | Profile page, email change with verification |
| 08 | [Active Storage & Action Text](./08-active-storage-and-action-text.md) | File uploads, Trix rich text editor |
| 09 | [Background Jobs](./09-background-jobs.md) | Solid Queue, Solid Cache, Solid Cable, recurring cleanup |
| 10 | [Example Resource (Posts)](./10-example-resource-posts.md) | Team-scoped CRUD with pagination, rich text, file attachments |
| 11 | [Landing Page & Articles](./11-landing-page-and-articles.md) | Example marketing homepage, static article system with Tailwind Typography |
| 12 | [Kamal & Litestream](./12-kamal-and-litestream.md) | Deployment config, Dockerfile, Litestream SQLite backups |
| 13 | [Polish & Extras](./13-polish-and-extras.md) | Error pages, admin impersonation, health check, AGENTS.md |

## Implementation Order

Phases should be implemented in order — each builds on the previous. Phase 4 (UI Helpers) comes before Phase 5 (Auth) because the auth views use `btn` and the form builder.

## Key Decisions

- **Tailwind**: Use `tailwindcss-rails` gem (not npm CLI). Simpler, no Node required in production.
- **Auth**: Emailed 6-digit codes, NOT magic links. No passwords anywhere.
- **Database**: SQLite for primary, queue, cache, and cable. Single-server deployment model.
- **Teams**: Every user gets a personal team on signup. All app records belong to a team.
- **Articles**: File-based static articles with YAML front matter (no database), rendered with Tailwind Typography.
- **Rich Text**: Action Text with Trix editor for the example Post resource.
- **Pagination**: Pagy with a custom Tailwind-styled nav helper.
