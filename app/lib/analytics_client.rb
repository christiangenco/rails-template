class AnalyticsClient
  def self.track(event_type:, request: nil, **attrs)
    return unless Rails.application.config.analytics.enabled
    return unless Rails.application.config.analytics.url.present?

    payload = { event_type: event_type, timestamp: Time.current.iso8601(3) }

    if request
      payload.merge!(
        path: request.path,
        method: request.method,
        ip: request.remote_ip,
        user_agent: request.user_agent,
        referrer: request.referrer,
        utm_source: request.params["utm_source"] || request.session["utm_source"],
        utm_medium: request.params["utm_medium"] || request.session["utm_medium"],
        utm_campaign: request.params["utm_campaign"] || request.session["utm_campaign"],
        request_id: request.request_id
      )
    end

    payload.merge!(attrs)
    AnalyticsBuffer.instance.push(payload.compact)
  end

  # error_or_string: an exception, or a plain string (reported as error_class "Notice").
  # Never raises to the caller; transport failures stay inside AnalyticsBatchJob.
  def self.notify(error_or_string, request: nil, **attrs)
    if error_or_string.is_a?(String)
      error_class = "Notice"
      message = error_or_string
      backtrace = nil
    else
      error_class = error_or_string.class.name
      message = error_or_string.message
      backtrace = error_or_string.backtrace&.first(20)
    end

    track(
      event_type: "exception",
      request: request,
      error_class: error_class,
      error_message: message,
      backtrace: backtrace,
      **attrs
    )
  rescue => e
    Rails.logger.error("[Analytics] notify failed: #{e.class}: #{e.message}")
  end

  def self.post_batch(events)
    url = Rails.application.config.analytics.url
    api_key = Rails.application.config.analytics.api_key

    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10

    req = Net::HTTP::Post.new(uri.path, {
      "Content-Type" => "application/json",
      "X-Api-Key" => api_key
    })
    req.body = { events: events }.to_json

    response = http.request(req)
    raise "Analytics batch post failed: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)
    response
  end
end
