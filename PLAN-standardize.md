# Plan: Standardize rails-template

This is the reference template for all other Rails projects. Changes here set the standard.

## 1. Rename MagicLink → VerificationCode

This is a mechanical rename. The system works identically — emailed 6-digit codes — it's just named wrong. Use offstageclub as the naming reference.

### Files to rename:
- `app/models/magic_link.rb` → `app/models/verification_code.rb` (class `MagicLink` → `VerificationCode`)
- `app/models/magic_link/code.rb` → `app/models/verification_code/code.rb` (module `MagicLink::Code` → `VerificationCode::Code`)
- `app/mailers/magic_link_mailer.rb` → `app/mailers/verification_code_mailer.rb` (class `MagicLinkMailer` → `VerificationCodeMailer`, method `sign_in_instructions` → `verification_email`)
- `app/views/magic_link_mailer/` → `app/views/verification_code_mailer/` (rename view files too)
- `app/controllers/sessions/magic_links_controller.rb` → `app/controllers/sessions/verification_codes_controller.rb` (class `Sessions::MagicLinksController` → `Sessions::VerificationCodesController`)
- `app/views/sessions/magic_links/` → `app/views/sessions/verification_codes/`

### Code changes:
- `config/routes.rb`: `resource :magic_link` → `resource :verification_code`
- `app/controllers/concerns/authentication.rb`: all `magic_link` references → `verification_code`:
  - `redirect_to_session_magic_link` → `redirect_to_verification_code`
  - `redirect_to_fake_session_magic_link` → `redirect_to_fake_verification_code`
  - `serve_development_magic_link` → `serve_development_verification_code`
  - `flash[:magic_link_code]` → `flash[:verification_code]`
  - `ensure_development_magic_link_not_leaked` → `ensure_development_verification_code_not_leaked`
  - `X-Magic-Link-Code` header → `X-Verification-Code`
  - `session_magic_link_path` → `session_verification_code_path`
- `app/models/user.rb`: `has_many :magic_links` → `has_many :verification_codes`, `send_magic_link` → `send_verification_code`
- `app/controllers/sessions_controller.rb`: `user.send_magic_link` → `user.send_verification_code`, `redirect_to_session_magic_link` → `redirect_to_verification_code`, `redirect_to_fake_session_magic_link` → `redirect_to_fake_verification_code`
- Database migration: rename `magic_links` table → `verification_codes`
- Update ALL tests referencing magic_link

### Verify:
- `bin/rails test` passes
- Routes work: `bin/rails routes | grep verification`

## 2. Bump Ruby to 3.4.8

1. `.ruby-version` → `3.4.8`
2. `Dockerfile` → `ARG RUBY_VERSION=3.4.8`
3. Gemfile already has `ruby file: ".ruby-version"` ✅
4. `bundle install`
5. `bin/rails test`

## 3. Commit

Make a single commit with message: "Rename MagicLink → VerificationCode, bump Ruby to 3.4.8"
