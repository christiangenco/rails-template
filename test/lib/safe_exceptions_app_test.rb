require "stringio"
require "test_helper"
require "safe_exceptions_app"

# The exceptions app must re-dispatch with no request data: no original query string, no cached
# query hash (Rack 3.2.8 Request#GET returns it verbatim), no raw body cache (ActionDispatch
# Request#body/#raw_post return RAW_POST_DATA when set), and no cached form parse results or
# errors. The original env must stay untouched for logging.
class SafeExceptionsAppTest < ActiveSupport::TestCase
  test "the dispatched env carries no original request data; the original env is unchanged" do
    seen = nil
    app = SafeExceptionsApp.new(->(env) { seen = env; [ 200, {}, [ "ok" ] ] })

    original = {
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/404",
      "QUERY_STRING" => "q=%FF%FE",
      "rack.input" => StringIO.new("a=%FF%FE"),
      "CONTENT_TYPE" => "application/x-www-form-urlencoded",
      "rack.request.query_hash" => { "q" => "\xFF\xFE" },
      "rack.request.form_hash" => { "a" => "\xFF\xFE" },
      "rack.request.form_pairs" => [ [ "a", "\xFF\xFE" ] ],
      "rack.request.form_vars" => "a=%FF%FE",
      "rack.request.form_error" => ArgumentError.new("boom"),
      "RAW_POST_DATA" => "a=%FF%FE"
    }
    status, = app.call(original)

    assert_equal 200, status
    assert_equal "", seen["QUERY_STRING"]
    assert_equal "", seen["rack.input"].read
    assert_not seen.key?("RAW_POST_DATA")
    assert_equal({}, seen["rack.request.query_hash"])
    assert_equal({}, seen["action_dispatch.request.query_parameters"])
    assert_equal({}, seen["action_dispatch.request.request_parameters"])
    assert_equal({}, seen["action_dispatch.request.parameters"])
    assert_not seen.key?("rack.request.form_hash")
    assert_not seen.key?("rack.request.form_pairs")
    assert_not seen.key?("rack.request.form_error")
    assert_equal "", seen["rack.request.form_vars"]

    # The original env (same object the re-dispatch came from) keeps everything for logging.
    assert_equal "q=%FF%FE", original["QUERY_STRING"]
    assert_equal "a=%FF%FE", original["RAW_POST_DATA"]
    assert_equal "a=%FF%FE", original["rack.request.form_vars"]
    assert_equal({ "q" => "\xFF\xFE" }, original["rack.request.query_hash"])
  end
end
