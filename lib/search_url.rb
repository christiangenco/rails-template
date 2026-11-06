# frozen_string_literal: true

require "uri"
require "base64"

# Offline, pure search-URL unwrapping. No network, never raises.
#
# Shared interface (see ~/tmp/misc-serper-unwrap-interface.md):
# - SearchUrl.unwrap(url) -> SearchUrl::Result
# - SearchUrl.wrapper?(url) -> true/false
#
# wrapper? matches by host AND path (google.com/url, /goto, /search;
# news.google.com/articles), never a blanket google.* rule: docs.google.com,
# sites.google.com, drive.google.com etc. are direct publisher URLs.
#
# The shared test cases live in test/fixtures/search_url_cases.json and are
# byte-identical to the copy in serper-cli (src/searchUrl.ts).
module SearchUrl
  # url:      candidate destination after unwrapping (nil for opaque/invalid).
  #           Not proven final: it may still HTTP-redirect; callers verify the
  #           final fetch URL and content before writing a source.
  # host:     lowercased publisher host, leading www. stripped (nil unless
  #           :direct/:unwrapped).
  # wrapped:  the input was a known wrapper.
  # wrapper:  outermost wrapper symbol detected, e.g. :google_url.
  # status:   :direct, :unwrapped, :opaque_wrapper, :invalid
  # reason:   short reason when not :direct/:unwrapped.
  Result = Data.define(:url, :host, :wrapped, :wrapper, :status, :reason)

  # Nested wrappers are unwrapped up to 3 levels; a 4th-level wrapper is invalid.
  MAX_UNWRAPS = 3

  TRACKING_KEYS = %w[gclid fbclid].freeze
  TRACKING_PREFIXES = ["utm_"].freeze

  OPAQUE_REASONS = {
    google_search: "google.com/search target not in URL",
    google_news: "news.google.com article id: target not in URL",
    google_goto: "google.com/goto without embedded target",
    vertex_grounding: "vertex grounding redirect id: target not in URL"
  }.freeze

  class << self
    def unwrap(url)
      unwrap_level(url, 0)
    end

    def wrapper?(url)
      return false unless url.is_a?(String) && !url.strip.empty?

      uri = safe_parse(url)
      return false unless uri.is_a?(URI::HTTP)

      !wrapper_for(normalized_host(uri.host), uri.path).nil?
    rescue URI::Error, ArgumentError
      false
    end

    private

    def unwrap_level(input, depth)
      unless input.is_a?(String) && !input.strip.empty?
        return invalid_result("empty or not a string")
      end

      uri = safe_parse(input.strip)
      return invalid_result("unparseable URL") if uri.nil?
      return invalid_result("non-http(s) scheme") unless uri.is_a?(URI::HTTP)
      return invalid_result("credentials in URL") if uri.user || uri.password
      return invalid_result("unparseable URL") if uri.host.nil? || uri.host.empty?

      host = normalized_host(uri.host)
      return invalid_result("IP literal host") if ip_literal?(host)
      return invalid_result("private host") if private_host?(host)

      wrapper = wrapper_for(host, uri.path)
      if wrapper.nil?
        return Result.new(
          url: normalize_url(uri), host: host, wrapped: false,
          wrapper: nil, status: :direct, reason: nil
        )
      end

      target = extract_target(wrapper, uri)
      if target.nil?
        # Opaque wrappers stay out of hit budgets and miss stamps; resolving
        # them needs a network step that is out of scope here.
        return Result.new(
          url: nil, host: nil, wrapped: true, wrapper: wrapper,
          status: :opaque_wrapper, reason: OPAQUE_REASONS[wrapper]
        )
      end

      if depth >= MAX_UNWRAPS
        return Result.new(
          url: nil, host: nil, wrapped: true, wrapper: wrapper,
          status: :invalid, reason: "wrapper nested more than 3 levels"
        )
      end

      inner = unwrap_level(target, depth + 1)
      case inner.status
      when :direct, :unwrapped
        Result.new(
          url: inner.url, host: inner.host, wrapped: true, wrapper: wrapper,
          status: :unwrapped, reason: nil
        )
      when :opaque_wrapper
        inner
      else # :invalid
        reason = inner.reason == "wrapper nested more than 3 levels" ? inner.reason : "unwrapped target: #{inner.reason}"
        Result.new(
          url: nil, host: nil, wrapped: true, wrapper: wrapper,
          status: :invalid, reason: reason
        )
      end
    rescue URI::Error, ArgumentError => e
      invalid_result("unparseable URL (#{e.class.name.split('::').last})")
    end

    def safe_parse(str)
      URI.parse(str)
    rescue URI::Error, ArgumentError
      nil
    end

    # Detection is by host AND path. Only exact "google.com" (after www.
    # stripping) is a Google wrapper; docs/sites/drive.google.com fall through.
    def wrapper_for(host, path)
      path = path.to_s.downcase
      case host
      when "google.com"
        return :google_url if path == "/url" || path.start_with?("/url/")
        return :google_goto if path == "/goto" || path.start_with?("/goto/")
        return :google_search if path.start_with?("/search")
        return :google_amp if path.start_with?("/amp/")
        nil
      when "news.google.com"
        return :google_news if path.start_with?("/articles")
        nil
      when "cdn.ampproject.org"
        return :google_amp if path.start_with?("/c/")
        nil
      when "bing.com"
        return :bing_ck if path.start_with?("/ck/a")
        nil
      when "duckduckgo.com"
        return :duckduckgo_l if path == "/l" || path.start_with?("/l/")
        nil
      when "vertexaisearch.cloud.google.com"
        return :vertex_grounding if path.start_with?("/grounding-api-redirect")
        nil
      end
      nil
    end

    def extract_target(wrapper, uri)
      case wrapper
      when :google_url, :google_goto
        query_param(uri, "q") || query_param(uri, "url")
      when :duckduckgo_l
        query_param(uri, "uddg")
      when :bing_ck
        decode_bing_u(query_param(uri, "u"))
      when :google_amp
        amp_target(uri.path)
      else # opaque wrappers carry no target in the URL
        nil
      end
    end

    def query_param(uri, name)
      URI.decode_www_form(uri.query.to_s).each do |key, value|
        return value if key == name
      end
      nil
    end

    # Bing encodes the target as base64url, usually behind an "a1" marker.
    def decode_bing_u(value)
      return nil if value.nil?

      [value, value.sub(/\Aa1/, "")].each do |candidate|
        padded = candidate + ("=" * ((4 - (candidate.length % 4)) % 4))
        decoded = Base64.urlsafe_decode64(padded)
        return decoded.force_encoding(Encoding::UTF_8) if decoded.start_with?("http://", "https://")
      rescue ArgumentError
        next
      end
      nil
    end

    # Paths look like /amp/s/example.com/page (https) or /c/example.com/page (http).
    def amp_target(path)
      rest = path.sub(%r{\A/(amp|c)/}, "")
      return nil if rest.empty?

      if rest.start_with?("s/")
        "https://#{rest[2..]}"
      else
        "http://#{rest}"
      end
    end

    # Lowercase scheme and host, drop the fragment, drop tracking params.
    def normalize_url(uri)
      host = uri.host.downcase
      port = uri.port
      default = uri.is_a?(URI::HTTPS) ? 443 : 80
      port_part = port == default ? "" : ":#{port}"
      path = uri.path.empty? ? "/" : uri.path

      kept = URI.decode_www_form(uri.query.to_s).reject do |key, _|
        TRACKING_KEYS.include?(key) || TRACKING_PREFIXES.any? { |p| key.downcase.start_with?(p) }
      end
      query = kept.empty? ? nil : URI.encode_www_form(kept)

      "#{uri.scheme.downcase}://#{host}#{port_part}#{path}#{query ? "?#{query}" : ""}"
    end

    def normalized_host(host)
      host = host.to_s.downcase.chomp(".")
      host = host.delete_prefix("www.") if host.start_with?("www.")
      host
    end

    def ip_literal?(host)
      return true if host.include?(":") # IPv6 literal

      parts = host.split(".")
      parts.length == 4 && parts.all? { |p| p.match?(/\A\d{1,3}\z/) }
    end

    def private_host?(host)
      host == "localhost" ||
        host.end_with?(".localhost", ".local", ".internal", ".lan", ".arpa")
    end

    def invalid_result(reason)
      Result.new(url: nil, host: nil, wrapped: false, wrapper: nil, status: :invalid, reason: reason)
    end
  end
end
