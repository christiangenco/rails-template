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

  # --create-smtp: credentials first, Mailgun login last, so a failure never leaves a live login
  # whose password nobody holds (Security LOW, Oct 30). No network: the script runs with a preload that
  # makes Net::HTTP.start raise, so even a wrong order can never reach Mailgun.
  FakeResponse = Struct.new(:code)

  class FakeMailgun
    attr_reader :requests, :start_args

    def initialize(code)
      @code = code
      @requests = []
    end

    def start(host, port, **opts)
      @start_args = [ host, port, opts ]
      yield self
    end

    def request(req)
      @requests << req
      FakeResponse.new(@code)
    end
  end

  test "create_mailgun_login posts the login to the Mailgun credentials API over TLS" do
    fake = FakeMailgun.new("200")

    SetupNewProject.create_mailgun_login(login: "widgetco@gxb.vc", password: "p" * 32, api_key: "k", http: fake)

    assert_equal [ "api.mailgun.net", 443, { use_ssl: true } ], fake.start_args
    req = fake.requests.sole
    assert_equal "POST", req.method
    assert_equal "/v3/domains/gxb.vc/credentials", req.path
    assert_equal "Basic #{[ 'api:k' ].pack('m0')}", req["Authorization"]
    assert_equal({ "login" => "widgetco@gxb.vc", "password" => "p" * 32 }, URI.decode_www_form(req.body).to_h)
  end

  test "create_mailgun_login raises with the HTTP code and never the password" do
    error = assert_raises(SetupNewProject::MailgunError) do
      SetupNewProject.create_mailgun_login(login: "widgetco@gxb.vc", password: "p" * 32, api_key: "k",
                                           http: FakeMailgun.new("401"))
    end
    assert_includes error.message, "HTTP 401"
    refute_includes error.message, "p" * 32
  end

  test "the Mailgun login is created only after the credentials are written" do
    calls = []
    SetupNewProject.write_credentials_then_create_login(
      write_credentials: -> { calls << :credentials }, create_login: -> { calls << :mailgun }
    )
    assert_equal %i[credentials mailgun], calls

    calls.clear
    assert_raises(RuntimeError) do
      SetupNewProject.write_credentials_then_create_login(
        write_credentials: -> { raise "credentials failed" }, create_login: -> { calls << :mailgun }
      )
    end
    assert_empty calls
  end

  def run_create_smtp_in(dir, rails_exit:)
    FileUtils.mkdir_p(File.join(dir, "bin"))
    FileUtils.mkdir_p(File.join(dir, "tmp"))
    FileUtils.mkdir_p(File.join(dir, "config"))
    fake_rails = File.join(dir, "bin/rails")
    # Records the plaintext file's mode while credentials:edit would read it.
    File.write(fake_rails, "#!/bin/sh\necho called > tmp/rails_called\n" \
                           "ls -l tmp/new_credentials.yml | cut -c1-10 > tmp/mode\n" \
                           "echo 0123456789abcdef0123456789abcdef > config/master.key\nexit #{rails_exit}\n")
    File.chmod(0o755, fake_rails)
    key_file = File.join(dir, "mailgun.env")
    File.write(key_file, "MAILGUN_API_KEY=fake-key-for-test\n")
    no_network = File.join(dir, "no_network.rb")
    File.write(no_network, "require 'net/http'\nclass << Net::HTTP\n  def start(*_args, **_opts)\n" \
                           "    raise Errno::ECONNREFUSED, 'test: network blocked'\n  end\nend\n")
    Open3.capture2e({ "MAILGUN_API_KEY_FILE" => key_file }, "ruby", "-r", no_network, SCRIPT,
                    "--name", "zzorder", "--server-ip", "203.0.113.1", "--create-smtp", chdir: dir)
  end

  test "a failed credentials step stops the script before any Mailgun call and leaves no plaintext file" do
    Dir.mktmpdir do |dir|
      out, status = run_create_smtp_in(dir, rails_exit: 1)

      refute status.success?
      assert File.exist?(File.join(dir, "tmp/rails_called")), out
      assert_includes out, "Command failed"
      refute_match(/Mailgun|network blocked/i, out)
      refute File.exist?(File.join(dir, "tmp/new_credentials.yml"))
    end
  end

  test "a stale 644 plaintext credentials file is replaced by a 600 one and deleted after" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "tmp"))
      stale = File.join(dir, "tmp/new_credentials.yml")
      File.write(stale, "stale")
      File.chmod(0o644, stale)

      out, _status = run_create_smtp_in(dir, rails_exit: 1)

      assert_equal "-rw-------", File.read(File.join(dir, "tmp/mode")).strip, out
      refute File.exist?(stale)
    end
  end

  test "a failed Mailgun call after the credentials step stops before the placeholders and says why" do
    Dir.mktmpdir do |dir|
      out, status = run_create_smtp_in(dir, rails_exit: 0)

      refute status.success?
      assert_includes out, "Error: the Mailgun login zzorder@gxb.vc was not created"
      assert_includes out, "no live login"
      assert_includes out, "network blocked"
      refute_includes out, "Updating config/deploy.yml"
      refute File.exist?(File.join(dir, "tmp/new_credentials.yml"))
    end
  end
end
