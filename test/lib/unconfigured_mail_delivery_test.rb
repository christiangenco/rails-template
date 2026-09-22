require "test_helper"

class UnconfiguredMailDeliveryTest < ActiveSupport::TestCase
  test "raises a clear message instead of attempting SMTP" do
    error = assert_raises(RuntimeError) { UnconfiguredMailDelivery.new.deliver!(nil) }
    assert_equal UnconfiguredMailDelivery::MESSAGE, error.message
  end
end
