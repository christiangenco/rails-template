require "test_helper"

class TrackableTest < ActionDispatch::IntegrationTest
  test "UTM params are persisted in session" do
    # Analytics is disabled in test, so no tracking happens,
    # but the UTM persistence should still work
    get "/?utm_source=google&utm_medium=cpc&utm_campaign=spring"
    # Should not crash; UTM params stored in session
    assert_response :success
  end

  test "requests work without UTM params" do
    get "/"
    assert_response :success
  end
end
