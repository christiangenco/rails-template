# Wraps the routed exceptions app (config.exceptions_app in production.rb). ShowExceptions
# re-dispatches the ORIGINAL request: same rack.input, QUERY_STRING, content type and the cached
# parse results/errors from the original dispatch. Error pages need none of that data, and reading
# it here parses the request body or query string — malformed data raises
# ActionController::BadRequest inside the exceptions app, which Rails answers with the failsafe
# 500 instead of the error page (Nov 2026: scanner POSTs with invalid encoding to unknown paths
# got 500s for an hour).
#
# So blank the request data out before the dispatch. GET keeps its routing; the errors controller
# renders from the status path alone.
require "stringio"

class SafeExceptionsApp
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(sanitized_env(env))
  end

  private

  def sanitized_env(env)
    env = env.dup
    env["rack.input"] = StringIO.new("")
    env["QUERY_STRING"] = ""
    env.delete("RAW_POST_DATA")
    env["action_dispatch.request.query_parameters"] = {}
    env["action_dispatch.request.request_parameters"] = {}
    env["action_dispatch.request.parameters"] = {}
    # Cached parse results and parse errors from the original request must not survive: Rack's
    # Request#GET returns the cached query_hash verbatim, and a cached form_error would be
    # re-raised as-is.
    env["rack.request.query_hash"] = {}
    env["rack.request.form_vars"] = ""
    env.delete("rack.request.form_pairs")
    env.delete("rack.request.form_hash")
    env.delete("rack.request.form_error")
    env
  end
end
