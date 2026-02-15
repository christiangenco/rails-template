# Phase 1: Scaffold & Databases

## Goal

Generate a fresh Rails 8 app with SQLite, importmaps, propshaft, and configure the multi-database setup for primary + queue + cache + cable.

## Steps

### 1.1 Generate the Rails app

```bash
cd ~/projects
rails new rails-template \
  --database=sqlite3 \
  --skip-stimulus \
  --skip-jbuilder \
  --skip-test \
  --css=tailwind
```

Notes:
- `--skip-stimulus` — we'll use Alpine.js instead
- `--skip-jbuilder` — not needed for this template
- `--skip-test` — we'll set up minitest manually with the right config
- `--css=tailwind` — installs `tailwindcss-rails` gem and initial config

After generation, re-add the test directory structure:
```bash
mkdir -p test/{models,controllers,integration,mailers,helpers,system}
```

### 1.2 Configure Gemfile

Replace the generated Gemfile with our curated set:

```ruby
source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false

# Frontend
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "tailwindcss-rails"
gem "rails_icons"

# Background jobs, caching, WebSockets — all SQLite-backed
gem "solid_queue"
gem "solid_cache"
gem "solid_cable"

# Pagination
gem "pagy", "~> 9.3"

# Rich text
gem "image_processing", "~> 1.2"

# Deployment
gem "kamal", require: false
gem "thruster", require: false

# Email
gem "premailer-rails"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
  gem "letter_opener"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "mocha"
end
```

Run `bundle install`.

### 1.3 Configure database.yml

Use SQLite for all databases, all stored in `storage/`:

```yaml
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  queue:
    <<: *default
    database: storage/development_queue.sqlite3
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: storage/development_cache.sqlite3
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: storage/development_cable.sqlite3
    migrations_paths: db/cable_migrate

test:
  primary:
    <<: *default
    database: storage/test.sqlite3
  queue:
    <<: *default
    database: storage/test_queue.sqlite3
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: storage/test_cache.sqlite3
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: storage/test_cable.sqlite3
    migrations_paths: db/cable_migrate

production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  queue:
    <<: *default
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
```

### 1.4 Configure production environment

In `config/environments/production.rb`, ensure:

```ruby
config.assume_ssl = true
config.force_ssl = true
```

### 1.5 Set up Procfile.dev

```
web: bin/rails server
css: bin/rails tailwindcss:watch
jobs: bin/jobs
```

### 1.6 Create bin/jobs

```bash
#!/usr/bin/env ruby
require_relative "../config/environment"
SolidQueue::Supervisor.start
```

Make it executable: `chmod +x bin/jobs`

### 1.7 Set up test_helper.rb

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
  fixtures :all
end
```

### 1.8 Configure .ruby-version

```
3.4.1
```

### 1.9 Run initial setup

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails solid_queue:install
bin/rails solid_cache:install
bin/rails solid_cable:install
```

## Verification

- `bin/rails server` starts without errors
- `bin/rails db:migrate` runs clean
- `bin/rails test` runs (no tests yet, but no errors)
- SQLite databases appear in `storage/`

## Files Created/Modified

- `Gemfile`
- `config/database.yml`
- `config/environments/production.rb`
- `Procfile.dev`
- `bin/jobs`
- `test/test_helper.rb`
- `.ruby-version`
