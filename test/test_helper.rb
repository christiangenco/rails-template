ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "webmock/minitest"

# No real network in tests: a test that reaches an outside host fails (Security, Nov 4).
# test/guards/fake_credentials_test.rb checks this block.
WebMock.disable_net_connect!(allow_localhost: true)

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
  fixtures :all
end
