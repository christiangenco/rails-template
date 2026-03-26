# Sends push notifications via self-hosted ntfy server (ntfy.gxb.vc).
#
# Setup:
#   Add to Rails credentials (bin/rails credentials:edit):
#     ntfy:
#       token: tk_your_token_here
#
# Usage:
#   Notification.send("christian", "🚨 Alert", "Something happened")
#   Notification.send("ricky", "📊 Report", "Monthly metrics ready", priority: "high")
#   Notification.send(%w[christian ricky], "👥 Team", "New signup!")
#
class Notification
  NTFY_URL = "https://ntfy.gxb.vc".freeze

  def self.send(topics, title, body, priority: "default")
    token = Rails.application.credentials.dig(:ntfy, :token)
    return Rails.logger.warn("Notification skipped: no ntfy token configured") unless token

    Array(topics).each do |topic|
      uri = URI("#{NTFY_URL}/#{topic}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Title"] = title
      request["Priority"] = priority
      request.body = body

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
    rescue => e
      Rails.logger.error("Notification failed for topic #{topic}: #{e.message}")
    end
  end
end
