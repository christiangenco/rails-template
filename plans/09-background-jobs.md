# Phase 9: Background Jobs

## Goal

Configure Solid Queue, Solid Cache, and Solid Cable — all backed by SQLite. Set up a recurring job to clean up expired magic links.

## Steps

### 9.1 Install Solid Queue

If not already done in Phase 1:

```bash
bin/rails solid_queue:install
```

This creates `db/queue_migrate/` with the Solid Queue schema migration and `config/queue.yml`.

Configure in `config/environments/production.rb`:
```ruby
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

Configure in `config/environments/development.rb`:
```ruby
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

### 9.2 Install Solid Cache

```bash
bin/rails solid_cache:install
```

Creates `db/cache_migrate/` and `config/cache.yml`.

Configure in `config/environments/production.rb`:
```ruby
config.cache_store = :solid_cache_store
config.solid_cache.connects_to = { database: { writing: :cache } }
```

### 9.3 Install Solid Cable

```bash
bin/rails solid_cable:install
```

Creates `db/cable_migrate/` and `config/cable.yml`.

Configure `config/cable.yml`:
```yaml
development:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
    polling_interval: 0.1.seconds
    message_retention: 1.day

test:
  adapter: test

production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
    polling_interval: 1.second
    message_retention: 1.day
```

### 9.4 Run migrations for all databases

```bash
bin/rails db:migrate
```

This will run migrations for primary, queue, cache, and cable databases.

### 9.5 Configure Solid Queue recurring tasks

Create or update `config/recurring.yml`:

```yaml
production:
  magic_link_cleanup:
    class: MagicLinkCleanupJob
    schedule: every hour
```

### 9.6 Create MagicLinkCleanupJob

Create `app/jobs/magic_link_cleanup_job.rb`:

```ruby
class MagicLinkCleanupJob < ApplicationJob
  queue_as :default

  def perform
    count = MagicLink.cleanup
    Rails.logger.info "Cleaned up #{count} expired magic links"
  end
end
```

### 9.7 Configure Puma for in-process Solid Queue (optional)

For single-server deployments, you can run Solid Queue inside Puma instead of a separate process. In `config/puma.rb`:

```ruby
# Run Solid Queue supervisor inside Puma for single-server deployments
if ENV["SOLID_QUEUE_IN_PUMA"]
  plugin :solid_queue
end
```

The `deploy.yml` in Phase 12 will set `SOLID_QUEUE_IN_PUMA: true` for simplicity. The `Procfile.dev` uses a separate `bin/jobs` process for development.

### 9.8 Ensure bin/jobs works

Verify `bin/jobs` from Phase 1 works:

```bash
#!/usr/bin/env ruby
require_relative "../config/environment"
SolidQueue::Supervisor.start
```

Test: `bin/jobs` starts and processes enqueued jobs.

### 9.9 Configure queue.yml

```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: 1
      polling_interval: 0.1

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

## Verification

- `bin/jobs` starts the Solid Queue supervisor
- Enqueuing a job (e.g., sending a magic link email) processes it
- `MagicLinkCleanupJob` runs and removes expired magic links
- `Rails.cache` works (try `Rails.cache.write("test", "value")` / `Rails.cache.read("test")`)
- ActionCable works over Solid Cable (optional — can verify later)

## Files Created/Modified

- `config/queue.yml`
- `config/cache.yml`
- `config/cable.yml`
- `config/recurring.yml`
- `config/puma.rb` (add solid_queue plugin)
- `config/environments/development.rb` (queue adapter, cache store)
- `config/environments/production.rb` (queue adapter, cache store)
- `app/jobs/magic_link_cleanup_job.rb`
- `db/queue_migrate/` (generated)
- `db/cache_migrate/` (generated)
- `db/cable_migrate/` (generated)
