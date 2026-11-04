# frozen_string_literal: true

# Guard test from the builder template (same file as avatars, pay and the other builder apps).
# Security, Oct 26: fail if a real key is loaded in tests, and print only NAMES, never values. Never use
# assert_empty or assert_equal on a credentials hash: on failure they print the whole decrypted file.
require "test_helper"

class FakeCredentialsTest < ActiveSupport::TestCase
  test "no production master key in the test environment" do
    assert(ENV["RAILS_MASTER_KEY"].to_s.empty?, "RAILS_MASTER_KEY is set in tests")
    assert(!File.exist?(Rails.root.join("config/master.key")), "config/master.key exists in the test checkout")
  end

  test "test credentials hold only fake values" do
    names = []
    walk = lambda do |prefix, value|
      if value.is_a?(Hash)
        value.each { |k, v| walk.call("#{prefix}#{k}.", v) }
      elsif value.is_a?(String) && !value.match?(/\A(fake|test|dummy|example)/i) && value.length >= 16
        names << prefix.chomp(".")
      end
    end
    walk.call("", Rails.application.credentials.config)
    assert(names.empty?, "credentials that do not look fake (names only): #{names.join(", ")}")
  end

  test "outside calls are blocked" do
    assert(WebMock::Config.instance.allow_net_connect == false, "WebMock must disable net connect in tests")
  end
end
