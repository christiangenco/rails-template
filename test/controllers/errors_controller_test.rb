require "stringio"
require "test_helper"

# Production sends errors to these routes (config.exceptions_app = routes). A missing page asked for in
# another format (/secrets.json, /x.yml, /env.txt) must still get the HTML error page and its own status,
# not a 500 from a missing .json/.yml/.txt view.
class ErrorsControllerTest < ActionDispatch::IntegrationTest
  %w[json yml txt xml].each do |ext|
    test "404 page answers 404 in HTML for .#{ext}" do
      get "/404.#{ext}"
      assert_response :not_found
      assert_equal "text/html", response.media_type
    end
  end

  test "422 and 500 pages answer in HTML for .json" do
    get "/422.json"
    assert_response :unprocessable_entity
    assert_equal "text/html", response.media_type
    get "/500.json"
    assert_response :internal_server_error
    assert_equal "text/html", response.media_type
  end

  # Production behavior: config.exceptions_app = routes (config/environments/production.rb). A scanner
  # POSTs a body with invalid encoding to a path that does not exist; Rails raises RoutingError, the
  # exceptions app re-dispatches to errors#not_found with the same bad body, and any callback there
  # that reads params parses the body and raises ActionController::BadRequest INSIDE the exceptions
  # app. Rails then logs "Error during failsafe response" and answers 500 instead of 404.
  test "POST with invalid encoding to unknown routes gets 404 or 400, never 500" do
    with_production_error_handling do
      [ "/", "/_next", "/api" ].each do |path|
        post path, params: "a=%FF%FE", headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
        assert_includes [ 404, 400 ], response.status,
          "#{path}: expected 404 or 400, got #{response.status} (500 = failsafe response)"
        assert_equal "text/html", response.media_type
        assert response.body.include?("Page not found"),
          "#{path}: expected the real 404 page HTML, got #{response.body.bytesize} bytes"
      end
    end
  end

  test "GET to an unknown path still gets the normal 404 page" do
    with_production_error_handling do
      get "/no/such/page"
      assert_response :not_found
      assert_equal "text/html", response.media_type
      assert response.body.include?("Page not found"),
        "expected the routed 404 page HTML, got #{response.body.bytesize} bytes"
    end
  end

  # The exceptions app re-dispatches the original env, so cached parse results travel with it: Rack
  # 3.2.8 Request#GET returns the cached rack.request.query_hash verbatim, and ActionDispatch
  # Request#body/#raw_post return RAW_POST_DATA when set. With malformed data cached there, the
  # error-page dispatch must still see neither — the wrapper blanks the caches, the query string and
  # the raw body — or the page failsafes to a 500 again.
  test "cached query hash, raw body and malformed query string in the env never reach the error page" do
    with_production_error_handling do
      get "/no/such/page", env: {
        "QUERY_STRING" => "q=%FF%FE",
        "rack.request.query_hash" => { "q" => "\xFF\xFE" },
        "RAW_POST_DATA" => "a=%FF%FE",
        "rack.input" => StringIO.new("a=%FF%FE"),
        "CONTENT_TYPE" => "application/x-www-form-urlencoded"
      }
      assert_response :not_found
      assert_equal "text/html", response.media_type
      assert response.body.include?("Page not found"),
        "expected the routed 404 page HTML, got #{response.body.bytesize} bytes"
    end
  end

  private

  # Turn on production's per-request error handling: exceptions flow through ShowExceptions to the
  # routes exceptions app (exceptions_app is set in config/environments/test.rb; it is boot-time
  # config). Without this, the test env's detailed debug page catches everything first.
  def with_production_error_handling
    old_show = Rails.application.env_config["action_dispatch.show_exceptions"]
    old_detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
    yield
  ensure
    Rails.application.env_config["action_dispatch.show_exceptions"] = old_show
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = old_detailed
  end
end
