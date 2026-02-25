# New Project Setup Script

## Goal

Create a `bin/setup-new-project` script that bootstraps a new project from this template, generating a fresh `master.key` while preserving shared secrets.

## Background

The template's Rails credentials contain secrets shared across all projects (GHCR token, Litestream keys). When creating a new project, we need a unique `master.key` but want to carry forward those shared secrets.

## Script Flow

1. Prompt for project name (used for `service`, `image`, directory name, etc.)
2. Prompt for server IP and domain
3. Read existing credentials using the template's master key
4. Extract shared secrets (ghcr token, litestream keys, etc.)
5. Delete `config/master.key` and `config/credentials.yml.enc`
6. Generate a fresh master key via `rails credentials:edit` (or `rails secret`)
7. Write shared secrets back into the new credentials file
8. Update `config/deploy.yml` placeholders (app name, server IP, domain, GitHub username)
9. Update `config/litestream.yml` with new app-specific S3 bucket/path
10. Print next steps: add `RAILS_MASTER_KEY` and `SSH_PRIVATE_KEY` to GitHub repo secrets

## Shared Secrets (carried forward)

- `ghcr.token` — GitHub Container Registry PAT (same across all projects)
- `litestream.access_key_id` — S3 access key for backups
- `litestream.secret_access_key` — S3 secret key for backups

## Per-Project Config (prompted or derived)

- App/service name
- Server IP
- Domain name
- GitHub username (for GHCR image path)
- S3 bucket/path for Litestream backups

## Implementation Notes

- Write as a Ruby script (`bin/setup-new-project`) so it can use `Rails.application.credentials`
- Could also be a plain bash script that calls `bin/rails runner` for credential operations
- Should be idempotent / safe to re-run (warn if master.key already differs from template)
- Consider storing the template master key somewhere recoverable (e.g. a constant in the script, or a `.template-master-key` file in `.gitignore`)
