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
end
