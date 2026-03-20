class AnalyticsClient
  def self.track(event_type:, request:, **attrs)
    return unless Rails.application.config.analytics.enabled
    return unless Rails.application.config.analytics.url.present?

    payload = {
      event_type: event_type,
      timestamp: Time.current.iso8601(3),
      path: request.path,
      method: request.method,
      ip: request.remote_ip,
      user_agent: request.user_agent,
      referrer: request.referrer,
      utm_source: request.params["utm_source"] || request.session["utm_source"],
      utm_medium: request.params["utm_medium"] || request.session["utm_medium"],
      utm_campaign: request.params["utm_campaign"] || request.session["utm_campaign"],
      request_id: request.request_id,
      **attrs
    }.compact

    AnalyticsBuffer.instance.push(payload)
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

    http.request(req)
  end
end
