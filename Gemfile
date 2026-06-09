source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1"
gem "sqlite3", ">= 2.1"
gem "puma", "~> 7.2"  # ~> 7.2 keeps us on the 7.x line: gets the 7.2.1 CVE fix, avoids the 8.0 major
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
