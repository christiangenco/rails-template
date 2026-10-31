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

  # The real-world case: an unknown path (scanner probe) asked for in a non-HTML format. The router
  # raises RoutingError and exceptions_app forwards to /404 with the original format still set.
  test "unknown path with Accept: application/json answers 404" do
    get "/secrets.json", headers: {"ACCEPT" => "application/json"}
    assert_response :not_found
  end

  %w[json yml txt].each do |ext|
    test "unknown path requested as .#{ext} answers 404" do
      get "/secrets.#{ext}"
      assert_response :not_found
    end
  end

  test "unknown HTML path still renders the 404 page" do
    get "/no/such/page"
    assert_response :not_found
    assert_equal "text/html", response.media_type
    assert_match "404", response.body
  end
end
