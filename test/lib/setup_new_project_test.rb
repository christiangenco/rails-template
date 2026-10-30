require "test_helper"
require "open3"

# bin/setup-new-project: one Litestream bucket and one key per app (Security, Oct 30).
class SetupNewProjectTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin/setup-new-project").to_s

  test "the default backup bucket is one bucket per app" do
    assert_equal "gxb-ls-widgetco", SetupNewProject.default_s3_bucket("widgetco")
    assert_equal "gxb-ls-my-app", SetupNewProject.default_s3_bucket("my-app")
  end

  test "the shared genco-backups bucket is refused" do
    error = assert_raises(ArgumentError) { SetupNewProject.check_s3_bucket!("genco-backups") }
    assert_match "genco-backups", error.message
    assert_equal "gxb-ls-widgetco", SetupNewProject.check_s3_bucket!("gxb-ls-widgetco")
  end

  # Deploys log in to GHCR with `gh auth token` (.kamal/secrets), so no app needs a token in credentials.
  test "the script reads nothing from the template credentials" do
    script = File.read(SCRIPT)
    refute_includes script, "bin/rails runner"
    refute_includes script, "Rails.application.credentials"
    refute SetupNewProject.const_defined?(:CARRIED_SECRETS)
    assert_includes Rails.root.join(".kamal/secrets").read, "KAMAL_REGISTRY_PASSWORD=$(gh auth token)"
  end

  test "new credentials hold only fresh values: no ghcr, litestream or spaces keys" do
    creds = SetupNewProject.credentials_hash(smtp_password: nil)

    assert_equal %w[active_record_encryption secret_key_base], creds.keys.sort
    refute creds.key?("ghcr")
    refute creds.key?("litestream")
    refute creds.key?("spaces")
    refute creds.key?("do_spaces")
    refute_match(/shared/, creds.to_yaml)
    assert_equal 128, creds["secret_key_base"].length
    assert_equal %w[deterministic_key key_derivation_salt primary_key], creds["active_record_encryption"].keys.sort
    refute creds.key?("mailgun")
  end

  test "new credentials hold the SMTP password when one is given" do
    creds = SetupNewProject.credentials_hash(smtp_password: "x" * 32)
    assert_equal({ "smtp_password" => "x" * 32 }, creds["mailgun"])
  end

  test "images go to ghcr.io/gxbvc and the registry login stays the GitHub user" do
    template = Rails.root.join("config/deploy.yml").read
    replacements = SetupNewProject.deploy_yml_replacements(
      app_name: "widgetco", domain: "widgetco.com", server_ip: "203.0.113.1",
      image_owner: SetupNewProject::IMAGE_OWNER, registry_user: SetupNewProject::REGISTRY_USER
    )
    deploy = replacements.reduce(template.dup) { |text, (find, replace)| text.gsub(find, replace) }

    assert_equal "gxbvc", SetupNewProject::IMAGE_OWNER
    assert_match(/^image: gxbvc\/widgetco$/, deploy)
    assert_match(/^  username: christiangenco$/, deploy)
    assert_match(/^service: widgetco$/, deploy)
    refute_includes deploy, "YOUR_GITHUB_USERNAME"
    refute_includes deploy, "christiangenco/widgetco"
  end

  test "the script help names the per-app default" do
    out, status = Open3.capture2e("ruby", SCRIPT, "--help")
    assert status.success?, out
    assert_includes out, "gxb-ls-NAME"
    refute_includes out, "default: genco-backups"
    assert_includes out, "--image-owner"
  end

  # Runs in an empty temp folder, so a missing check can never touch this repo's credentials.
  test "the script refuses --s3-bucket genco-backups before it changes anything" do
    Dir.mktmpdir do |dir|
      out, status = Open3.capture2e("ruby", SCRIPT, "--name", "zzbuckettest", "--server-ip", "203.0.113.1",
                                    "--no-mail", "--s3-bucket", "genco-backups", chdir: dir)
      refute status.success?
      assert_includes out, "Error: genco-backups is the shared bucket"
      refute_includes out, "Setting up new project"
      assert_empty Dir.children(dir)
    end
  end
end
