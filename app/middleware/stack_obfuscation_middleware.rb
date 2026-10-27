class StackObfuscationMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    headers.delete("X-Runtime")
    headers.delete("X-Request-Id")
    headers["X-Powered-By"] = "Next.js"

    [status, headers, response]
  end
end
