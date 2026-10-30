# frozen_string_literal: true

require "securerandom"
require "net/http"

# Pure helpers for bin/setup-new-project (kept here so they have tests).
#
# One Litestream backup bucket and one key per app (Christian, Oct 26; Security, Oct 30).
# A new app never gets the shared genco-backups bucket or the template's Litestream or
# Spaces keys. Make its own bucket and key with:
#   ~/projects/hq/bin/ls-bucket-per-app provision APP DIR
module SetupNewProject
  SHARED_BUCKET = "genco-backups"
  BUCKET_PREFIX = "gxb-ls-"

  # Images go to ghcr.io/gxbvc/<app> (GXB org). The registry login is the GitHub user whose
  # `gh auth token` .kamal/secrets passes as KAMAL_REGISTRY_PASSWORD.
  IMAGE_OWNER = "gxbvc"
  REGISTRY_USER = "christiangenco"

  MAILGUN_API = "https://api.mailgun.net/v3"
  class MailgunError < StandardError; end

  module_function

  def default_s3_bucket(app_name)
    "#{BUCKET_PREFIX}#{app_name}"
  end

  def check_s3_bucket!(bucket)
    if bucket == SHARED_BUCKET
      raise ArgumentError, "#{SHARED_BUCKET} is the shared bucket. Each app gets its own bucket " \
                           "(#{BUCKET_PREFIX}NAME, the default) and its own key."
    end
    bucket
  end

  # Placeholder => value for config/deploy.yml. The image line goes first, so its
  # YOUR_GITHUB_USERNAME becomes the image owner and the rest become the registry user.
  def deploy_yml_replacements(app_name:, domain:, server_ip:, image_owner:, registry_user:)
    {
      "service: myapp" => "service: #{app_name}",
      "image: YOUR_GITHUB_USERNAME/myapp" => "image: #{image_owner}/#{app_name}",
      "YOUR_SERVER_IP" => server_ip,
      "YOUR_GITHUB_USERNAME" => registry_user,
      "myapp.com" => domain,
      "myapp_storage" => "#{app_name}_storage"
    }
  end

  def mailgun_api_key(path)
    raw = File.read(path)
    raw[/^MAILGUN_API_KEY=["']?([^"'\s]+)/, 1] || raw.strip
  end

  # Creates the Mailgun SMTP login. Errors name the login and the HTTP code, never the password.
  def create_mailgun_login(login:, password:, api_key:, http: Net::HTTP)
    uri = URI("#{MAILGUN_API}/domains/#{login.split('@').last}/credentials")
    req = Net::HTTP::Post.new(uri)
    req.basic_auth("api", api_key)
    req.set_form_data("login" => login, "password" => password)
    res = http.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
    raise MailgunError, "Mailgun did not create #{login} (HTTP #{res.code})" unless res.code == "200"
  end

  # Credentials first, Mailgun login last (Security LOW, Oct 30). If writing the credentials fails,
  # no login exists. If the login fails, the credentials hold a password that no login uses.
  # Either way there is never a live login whose password nobody holds.
  def write_credentials_then_create_login(write_credentials:, create_login: nil)
    write_credentials.call
    create_login&.call
  end

  # Credentials for the new app: fresh values only. Nothing is copied from the template's
  # credentials. GHCR: .kamal/secrets passes `gh auth token` at deploy time. Litestream:
  # ls-bucket-per-app writes the app's own key.
  def credentials_hash(smtp_password:)
    creds = {
      "secret_key_base" => SecureRandom.hex(64),
      "active_record_encryption" => {
        "primary_key" => SecureRandom.alphanumeric(32),
        "deterministic_key" => SecureRandom.alphanumeric(32),
        "key_derivation_salt" => SecureRandom.alphanumeric(32)
      }
    }
    creds["mailgun"] = { "smtp_password" => smtp_password } if smtp_password
    creds
  end
end
