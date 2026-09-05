# Sends push notifications to the GXB iOS app via chat.gxb.vc, falling back to the
# legacy ntfy server (ntfy.gxb.vc) for people who do not have the app installed.
#
# Setup:
#   Add to Rails credentials (bin/rails credentials:edit):
#     notify:
#       publish_token: <alert-only token from chat's credentials>
#     ntfy:
#       token: tk_your_token_here   # only needed for the ntfy fallback topics
#
# Usage:
#   Notification.send("christian", "🚨 Alert", "Something happened")
#   Notification.send("ricky", "📊 Report", "Monthly metrics ready", priority: "high")
#   Notification.send(%w[christian ricky], "👥 Team", "New signup!")
#
# Returns true when every topic was delivered, false otherwise. Delivery failures are
# logged and never raise, so an ancillary notification cannot break the operation that
# triggered it. Callers that record "notified" state should check the return value.
class Notification
  NTFY_URL = "https://ntfy.gxb.vc".freeze
  PUBLISH_URL = "https://chat.gxb.vc/notify".freeze

  # Topics whose owner has the GXB app installed. Everyone else stays on ntfy so their
  # notifications are not silently dropped.
  APNS_TOPICS = %w[christian].freeze

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  def self.send(topics, title, body, priority: "default")
    Array(topics).map do |topic|
      if APNS_TOPICS.include?(topic)
        send_apns(topic, title, body)
      else
        send_ntfy(topic, title, body, priority)
      end
    rescue => e
      Rails.logger.error("Notification failed for topic #{topic}: #{e.message}")
      false
    end.all?
  end

  def self.send_apns(topic, title, body)
    token = Rails.application.credentials.dig(:notify, :publish_token)
    return Rails.logger.warn("Notification skipped: no notify publish token configured") && false unless token

    uri = URI("#{PUBLISH_URL}/#{topic}")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Title"] = title
    request["Content-Type"] = "text/plain"
    request.body = body

    post(uri, request, topic)
  end

  def self.send_ntfy(topic, title, body, priority)
    token = Rails.application.credentials.dig(:ntfy, :token)
    return Rails.logger.warn("Notification skipped: no ntfy token configured") && false unless token

    uri = URI("#{NTFY_URL}/#{topic}")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Title"] = title
    request["Priority"] = priority
    request.body = body

    post(uri, request, topic)
  end

  # Unlike the previous implementation, this checks the HTTP status instead of discarding
  # it, so a rejected notification is visible in the log rather than silently lost.
  def self.post(uri, request, topic)
    response = Net::HTTP.start(
      uri.hostname, uri.port,
      use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT
    ) { |http| http.request(request) }

    return true if response.is_a?(Net::HTTPSuccess)

    Rails.logger.error("Notification rejected for topic #{topic}: HTTP #{response.code} #{response.body.to_s.truncate(200)}")
    false
  end
end
