require "test_helper"

# User.domain_of reads the domain of ONE plain mailbox using an allowlist of
# characters. Any other shape returns nil, so code such as
# `User.domain_of(email) == "gxb.vc"` cannot be fooled by a list like
# "x@evil.com, y@gxb.vc" or an RFC 2047 encoded-word local part.
class UserEmailDomainTest < ActiveSupport::TestCase
  ATTACKS = [
    "x@evil.com, y@gxb.vc",
    "x@evil.com,y@gxb.vc",
    "x@evil.com\ny@gxb.vc",
    "Y <y@gxb.vc>",
    "y@gxb.vc.evil.com",
    "=?utf-8?q?x=40evil.test=2c?=@gxb.vc",
    "x%40evil.test@gxb.vc",
    "x=y@gxb.vc",
    "x?y@gxb.vc",
    "\"x\"@gxb.vc"
  ].freeze

  ATTACKS.each do |attack|
    test "domain_of does not report gxb.vc for #{attack.inspect}" do
      assert_not_equal "gxb.vc", User.domain_of(attack)
    end

    test "a gxb.vc check refuses #{attack.inspect}" do
      assert_not User.email_in_domain?(attack, "gxb.vc")
    end
  end

  test "domain_of is nil for blank and non-string input" do
    assert_nil User.domain_of(nil)
    assert_nil User.domain_of("")
    assert_nil User.domain_of("no-at-sign")
  end

  test "domain_of ignores case and surrounding spaces" do
    assert_equal "gxb.vc", User.domain_of("Y@GXB.VC")
    assert_equal "gxb.vc", User.domain_of("  y@gxb.vc ")
    assert User.email_in_domain?("Y@GXB.VC", "gxb.vc")
  end

  test "normal staff emails are accepted" do
    assert User.email_in_domain?("christian@gxb.vc", "gxb.vc")
    assert User.email_in_domain?("christian@gxb.vc", %w[gxb.vc gen.co])
    assert User.email_in_domain?("first.last+tag@gxb.vc", "gxb.vc")
    assert User.email_in_domain?("a_b-c@gxb.vc", "gxb.vc")
  end
end
