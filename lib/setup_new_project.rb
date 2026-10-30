# frozen_string_literal: true

require "securerandom"

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

  # Template credentials copied into the new app: name => credentials path.
  # Only the GHCR token. Never litestream, spaces or do_spaces keys.
  CARRIED_SECRETS = { "ghcr_token" => %i[ghcr token] }.freeze

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

  # Ruby for `bin/rails runner` that prints the carried secrets as JSON.
  def read_carried_secrets_snippet
    pairs = CARRIED_SECRETS.map { |name, path| "#{name}: creds.dig(#{path.map(&:inspect).join(', ')})" }
    "creds = Rails.application.credentials; puts({ #{pairs.join(', ')} }.to_json)"
  end

  # Credentials for the new app. Only CARRIED_SECRETS are read from `secrets`; any other key is ignored.
  def credentials_hash(secrets, smtp_password:)
    creds = {
      "secret_key_base" => SecureRandom.hex(64),
      "ghcr" => { "token" => secrets["ghcr_token"] },
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
