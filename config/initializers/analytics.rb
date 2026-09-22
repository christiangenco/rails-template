Rails.application.config.analytics = ActiveSupport::OrderedOptions.new
Rails.application.config.analytics.url = ENV["ANALYTICS_URL"] # e.g. https://analytics.gxb.vc/api/v1/events
Rails.application.config.analytics.api_key = Rails.application.credentials.dig(:analytics, :api_key)
Rails.application.config.analytics.enabled = Rails.env.production? || ENV["ANALYTICS_ENABLED"] == "true"

require_relative "../../app/middleware/analytics_middleware"
Rails.application.config.middleware.use AnalyticsMiddleware

at_exit { AnalyticsBuffer.instance.flush if defined?(AnalyticsBuffer) }

# Reports every unhandled exception Rails knows about: controllers (including
# API controllers), jobs, and mailers. Not autoloaded: a class defined here
# can't be reloaded from app/, so it's safe to define and subscribe once at boot.
class AnalyticsErrorSubscriber
  def report(error, handled:, severity:, context:, source: nil)
    controller = context[:controller]
    job = context[:job]
    request = controller&.request

    # config.exceptions_app rewrites the env to GET /500 before the error
    # reporter runs, so the route that actually failed is only in these headers.
    original = {
      path: request&.env&.[]("action_dispatch.original_path"),
      method: request&.env&.[]("action_dispatch.original_request_method")
    }.compact

    AnalyticsClient.notify(
      error,
      request: request,
      user_id: Current.user&.id&.to_s,
      properties: {
        handled: handled, severity: severity, source: source,
        job: job&.class&.name, job_id: job&.job_id, executions: job&.executions,
        queue: job&.queue_name, job_arguments: job && job_arguments_summary(job)
      }.compact,
      **original
    )
  end

  private

  # Mailer arguments carry recipient addresses and message bodies; every
  # other job type just gets a count, since we don't know what's safe to
  # show for an arbitrary job's payload.
  def job_arguments_summary(job)
    if job.is_a?(ActionMailer::MailDeliveryJob)
      mailer, method = job.arguments.first(2)
      "#{mailer}##{method}"
    else
      "#{job.arguments.size} argument(s)"
    end
  end
end
Rails.error.subscribe(AnalyticsErrorSubscriber.new)

# Attaches slow queries to the current request's env so AnalyticsMiddleware can
# fold them into the SlowRequest ticket. No standalone `sql` event. Capped per
# request so a query storm can't inflate a single event payload.
ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
  next if event.duration < 100 || event.payload[:name] == "SCHEMA" || event.payload[:cached]
  env = ActiveSupport::ExecutionContext.to_h[:controller]&.request&.env or next
  slow_sql = (env["analytics.slow_sql"] ||= [])
  next if slow_sql.size >= 20
  slow_sql << {
    name: event.payload[:name],
    ms: event.duration.round,
    sql: event.payload[:sql].to_s.gsub(/'[^']*'/, "?").truncate(500)
  }
end
