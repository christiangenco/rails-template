# Switch Rails Template to GHCR + Fix Tailwind v4 overlayfs Bug

## Background

The GXB site has been successfully migrated from a local Docker registry to GHCR (GitHub Container Registry). The rails-template should be updated to match, since it's the starting point for new projects.

Tested and working: both local (`bin/kamal deploy`) and CI (GitHub Actions push to main) deployments succeed.

### Tailwind v4 overlayfs bug

Tailwind v4's Rust-based oxide filesystem scanner produces incomplete CSS output when run inside Docker's overlayfs during `docker build` — regardless of native vs QEMU architecture. The fix is a three-part workaround:

1. **`.kamal/hooks/pre-build`** — builds Tailwind CSS on the host machine (no overlayfs) before Docker build starts
2. **`builder.context: .`** in deploy.yml — tells Kamal to use the working directory as Docker context instead of a git clone (which would wipe the pre-built CSS via `git clean -fdx`)
3. **`SKIP_TAILWIND_BUILD=1`** in Dockerfile + `lib/tasks/skip_tailwind.rake` — skips Tailwind during Docker's `assets:precompile` since it's already pre-built

## Files to Change

### 1. `config/deploy.yml`

Replace registry section:
```yaml
# Before
registry:
  server: localhost:5555

# After
registry:
  server: ghcr.io
  username: YOUR_GITHUB_USERNAME
  password:
    - KAMAL_REGISTRY_PASSWORD
```

Update image name:
```yaml
image: YOUR_GITHUB_USERNAME/myapp
```

Replace builder section:
```yaml
# Before
builder:
  arch: amd64
  remote: ssh://root@YOUR_SERVER_IP
  local: false

# After — build locally, push to GHCR
# context: . ensures Docker uses the working directory (not a git clone)
# so the pre-built Tailwind CSS from .kamal/hooks/pre-build is included.
builder:
  arch: amd64
  context: .
```

### 2. `.kamal/secrets`

Add GHCR registry password line:
```bash
# GitHub Container Registry (ghcr.io) token
KAMAL_REGISTRY_PASSWORD=$(bin/rails r "puts Rails.application.credentials.dig(:ghcr, :token)")
```

### 3. `Dockerfile`

Change:
```dockerfile
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
```
to:
```dockerfile
# Tailwind CSS is pre-built on the host via .kamal/hooks/pre-build
# to work around Tailwind v4's overlayfs scanner bug during docker build
RUN SECRET_KEY_BASE_DUMMY=1 SKIP_TAILWIND_BUILD=1 ./bin/rails assets:precompile
```

### 4. New file: `.kamal/hooks/pre-build` (chmod +x)

```bash
#!/bin/sh
# Pre-build hook: build Tailwind CSS on the host machine before Docker build.
#
# Tailwind CSS v4's Rust-based oxide filesystem scanner produces incomplete
# output when run inside Docker's overlayfs during build. Building on the
# host avoids this issue. The Dockerfile skips the Tailwind build step
# (SKIP_TAILWIND_BUILD=1) and uses this pre-built CSS instead.

set -e

echo "Pre-building Tailwind CSS on host..."
bin/rails tailwindcss:build
echo "Tailwind CSS built successfully."
```

### 5. New file: `lib/tasks/skip_tailwind.rake`

```ruby
# Skip Tailwind CSS build during Docker image builds.
# Tailwind v4's Rust filesystem scanner produces incomplete output when run
# inside Docker's overlayfs during build. Instead, we pre-build tailwind.css
# on the host via .kamal/hooks/pre-build and COPY it into the Docker image.
if ENV["SKIP_TAILWIND_BUILD"]
  Rake::Task["tailwindcss:build"].clear
  namespace :tailwindcss do
    task build: :environment do
      puts "Skipping Tailwind build (SKIP_TAILWIND_BUILD is set, using pre-built CSS)"
    end
  end
end
```

### 6. `.github/workflows/ci.yml`

The deploy job just needs SSH access and master key file — no buildkit hackery needed.
Remove any "Configure remote buildkit for insecure registry" steps.
The pre-build hook runs automatically as part of `bin/kamal deploy` on the CI runner.

### 7. `AGENTS.md`

Update the Deployment section to document:
- GHCR instead of local registry
- Tailwind v4 overlayfs workaround (pre-build hook + context: . + skip in Docker)
- GitHub Secrets: `SSH_PRIVATE_KEY`, `RAILS_MASTER_KEY` (GHCR token lives in Rails credentials)
- Remove "Registry maintenance" section

## Setup Instructions for New Projects

When creating a new project from this template:
1. Create a GitHub PAT (classic) with `repo` + `write:packages` scopes
2. Add it to Rails credentials: `bin/rails credentials:edit` → `ghcr: { token: "ghp_..." }`
3. Log into GHCR on the server: `ssh root@SERVER "echo 'TOKEN' | docker login ghcr.io -u USERNAME --password-stdin"`
4. Set `RAILS_MASTER_KEY` and `SSH_PRIVATE_KEY` as GitHub repo secrets (for CI deploys)
