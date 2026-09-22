# Job failures never reach analytics on their own: Solid Queue has no retry
# mechanism of its own, it relies entirely on Active Job's retry_on/discard_on,
# and a job with neither just fails silently into solid_queue_failed_executions.
# This wires the same Rails.error pipeline AnalyticsErrorSubscriber already
# listens on for controllers and mailers, following the pattern Solid Queue's
# own README recommends ("Error reporting on jobs").
#
# ActionMailer::MailDeliveryJob doesn't inherit from ApplicationJob, so it
# needs its own hook. It also already has its own rescue_from(StandardError)
# that delegates to the target mailer's own rescue_from (for mailers that mean
# to swallow one specific error) -- call that first, and only report+reraise
# what it doesn't handle, so mail delivery keeps its existing behavior.
module JobFailureReporting
  # A bad credential fails every queued mail identically; this keeps that
  # from filing one issue per occurrence. Keyed by job class, queue and
  # exception class, not by arguments.
  WINDOW_SECONDS = 300

  @mutex = Mutex.new
  @seen_at = {}

  class << self
    def report(job, exception)
      return if recently_reported?(job, exception)

      Rails.error.report(exception, handled: false, source: "application.active_job", context: { job: job })
    end

    # Test-only: the window is process-global, so tests that reuse a job or
    # exception class need to clear it between examples.
    def reset!
      @mutex.synchronize { @seen_at.clear }
    end

    private

    def recently_reported?(job, exception)
      key = [ job.class.name, job.queue_name, exception.class.name ]
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @mutex.synchronize do
        last_reported_at = @seen_at[key]
        if last_reported_at && now - last_reported_at < WINDOW_SECONDS
          true
        else
          @seen_at[key] = now
          false
        end
      end
    end
  end
end

# ApplicationJob is autoloaded, so a reload in development would otherwise
# drop this handler along with the old class object; to_prepare re-attaches
# it after every reload (a no-op in production, which never reloads).
Rails.application.reloader.to_prepare do
  ApplicationJob.rescue_from(Exception) do |exception|
    JobFailureReporting.report(self, exception)
    raise exception
  end
end

# ActionMailer::MailDeliveryJob is a framework class, loaded once and never
# reloaded, so it only needs registering here at boot.
ActionMailer::MailDeliveryJob.rescue_from(Exception) do |exception|
  begin
    handle_exception_with_mailer_class(exception)
  rescue Exception => unhandled
    JobFailureReporting.report(self, unhandled)
    raise unhandled
  end
end
