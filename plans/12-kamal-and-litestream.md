# Phase 12: Kamal & Litestream

## Goal

Configure Kamal 2 for deployment and Litestream as a sidecar accessory for continuous SQLite backups to S3-compatible storage (e.g., DigitalOcean Spaces, AWS S3, Backblaze B2).

## Steps

### 12.1 Dockerfile

Create `Dockerfile` based on the standard Rails 8 template (ported from offstageclub):

```dockerfile
# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.4.1
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Build stage
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage
FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
```

Key points:
- Uses jemalloc for reduced memory usage
- Includes `libvips` for Active Storage image processing
- Includes `sqlite3` for the database
- Multi-stage build to keep the final image small
- Uses Thruster for HTTP compression and caching
- Runs as non-root `rails` user

### 12.2 Docker Entrypoint

Create `bin/docker-entrypoint`:

```bash
#!/bin/bash -e

# Enable jemalloc for reduced memory usage and target latency.
if [ -z "${LD_PRELOAD+x}" ] && [ -f /usr/local/lib/libjemalloc.so ]; then
  export LD_PRELOAD=/usr/local/lib/libjemalloc.so
fi

# If running the rails server then create or migrate existing database
if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  ./bin/rails db:prepare
fi

exec "${@}"
```

Make executable: `chmod +x bin/docker-entrypoint`

### 12.3 config/deploy.yml

```yaml
service: myapp
image: myapp

servers:
  web:
    - YOUR_SERVER_IP

# SSL via Let's Encrypt (requires DNS pointing to server)
# Using Cloudflare? Set encryption mode to "Full" in SSL/TLS settings.
proxy:
  ssl: true
  host: myapp.com

# Container registry — local registry for self-hosted
# For Docker Hub, use: server: docker.io
registry:
  server: localhost:5555

env:
  secret:
    - RAILS_MASTER_KEY
  clear:
    # Run Solid Queue inside Puma (single-server deployment)
    SOLID_QUEUE_IN_PUMA: true
    WEB_CONCURRENCY: 1

# Persistent storage volume for SQLite databases and Active Storage files
volumes:
  - "myapp_storage:/rails/storage"

# Bridge assets between deploys (avoid 404 on in-flight requests)
asset_path: /rails/public/assets

# Builder config
builder:
  arch: amd64

# Litestream sidecar for continuous SQLite backups
accessories:
  litestream:
    image: litestream/litestream:0.3
    host: YOUR_SERVER_IP
    files:
      - config/litestream.yml:/etc/litestream.yml
    volumes:
      - "myapp_storage:/storage"
    env:
      secret:
        - LITESTREAM_ACCESS_KEY_ID
        - LITESTREAM_SECRET_ACCESS_KEY
    cmd: "replicate"

# Useful aliases
aliases:
  console: app exec --interactive --reuse "bin/rails console"
  shell: app exec --interactive --reuse "bash"
  logs: app logs -f
  dbc: app exec --interactive --reuse "bin/rails dbconsole"
```

### 12.4 config/litestream.yml

Litestream continuously replicates SQLite WAL changes to S3-compatible storage. This gives you point-in-time recovery.

```yaml
dbs:
  # Primary database
  - path: /storage/production.sqlite3
    replicas:
      - type: s3
        bucket: your-backups-bucket
        path: myapp/production.sqlite3
        endpoint: https://nyc3.digitaloceanspaces.com

  # Queue database
  - path: /storage/production_queue.sqlite3
    replicas:
      - type: s3
        bucket: your-backups-bucket
        path: myapp/production_queue.sqlite3
        endpoint: https://nyc3.digitaloceanspaces.com

  # Cache database (optional — can be rebuilt)
  - path: /storage/production_cache.sqlite3
    replicas:
      - type: s3
        bucket: your-backups-bucket
        path: myapp/production_cache.sqlite3
        endpoint: https://nyc3.digitaloceanspaces.com

  # Cable database (optional — ephemeral data)
  - path: /storage/production_cable.sqlite3
    replicas:
      - type: s3
        bucket: your-backups-bucket
        path: myapp/production_cable.sqlite3
        endpoint: https://nyc3.digitaloceanspaces.com
```

Notes:
- The `endpoint` should match your S3-compatible storage provider
- For AWS S3, remove the `endpoint` line and set the `region`
- Cache and cable databases are optional to backup (they're ephemeral), but it doesn't hurt
- Litestream reads the `LITESTREAM_ACCESS_KEY_ID` and `LITESTREAM_SECRET_ACCESS_KEY` env vars automatically

### 12.5 .kamal/secrets

```bash
# Secrets for Kamal deployment
# Pull from Rails credentials or environment variables — NEVER hardcode here

RAILS_MASTER_KEY=$(cat config/master.key)

# Litestream S3 credentials (from Rails credentials)
LITESTREAM_ACCESS_KEY_ID=$(bin/rails r "puts Rails.application.credentials.dig(:litestream, :access_key_id)")
LITESTREAM_SECRET_ACCESS_KEY=$(bin/rails r "puts Rails.application.credentials.dig(:litestream, :secret_access_key)")
```

### 12.6 Store Litestream credentials in Rails credentials

```bash
bin/rails credentials:edit
```

Add:
```yaml
litestream:
  access_key_id: YOUR_S3_ACCESS_KEY
  secret_access_key: YOUR_S3_SECRET_KEY
```

### 12.7 .dockerignore

Create `.dockerignore` to keep the image small:

```
.git
.gitignore
log/*
tmp/*
storage/*
node_modules
.kamal
config/master.key
config/credentials/*.key
```

### 12.8 Configure production.rb for Kamal

Ensure `config/environments/production.rb` has:

```ruby
config.assume_ssl = true
config.force_ssl = true

# Store files on local disk (volume-mounted in Docker)
config.active_storage.service = :local

# Use Solid Queue for background jobs
config.active_job.queue_adapter = :solid_queue

# Use Solid Cache for Rails.cache
config.cache_store = :solid_cache_store
```

### 12.9 Restoration Process (document in README)

To restore from a Litestream backup:

```bash
# Install litestream locally
# See: https://litestream.io/install/

# Restore the database
litestream restore -o production.sqlite3 \
  s3://your-backups-bucket/myapp/production.sqlite3 \
  -endpoint https://nyc3.digitaloceanspaces.com

# Copy to server
scp production.sqlite3 root@YOUR_SERVER_IP:/var/lib/docker/volumes/myapp_storage/_data/
```

## Verification

Before first deploy:
- `docker build -t myapp .` succeeds locally
- `config/deploy.yml` has correct server IP, domain, and registry
- `config/litestream.yml` has correct bucket and paths
- `.kamal/secrets` correctly reads Rails credentials
- Litestream credentials are stored in Rails credentials

First deploy:
- `kamal setup` initializes the server
- `kamal deploy` builds, pushes, and deploys
- `kamal app logs` shows Rails starting successfully
- `kamal accessory logs litestream` shows Litestream replicating
- App is accessible via HTTPS at the configured domain

Ongoing:
- `kamal deploy` deploys new versions
- `kamal console` opens a Rails console on the server
- `kamal logs` tails production logs

## Files Created/Modified

- `Dockerfile`
- `bin/docker-entrypoint`
- `config/deploy.yml`
- `config/litestream.yml`
- `.kamal/secrets`
- `.dockerignore`
- `config/environments/production.rb` (update)
- `config/credentials.yml.enc` (add litestream keys)
