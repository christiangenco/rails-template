# frozen_string_literal: true

require "test_helper"
require "json"
require "search_url"

class SearchUrlTest < ActiveSupport::TestCase
  CASES_PATH = Rails.root.join("test/fixtures/search_url_cases.json")
  CASES = JSON.parse(File.read(CASES_PATH))

  test "shared cases (byte-identical JSON shared with serper-cli)" do
    CASES.each_with_index do |tc, i|
      result = SearchUrl.unwrap(tc["input"])
      exp = tc["expected"]

      assert_field(exp["status"], result.status&.to_s, "status", i, tc)
      assert_field(exp["url"], result.url, "url", i, tc)
      assert_field(exp["host"], result.host, "host", i, tc)
      assert_field(exp["wrapped"], result.wrapped, "wrapped", i, tc)
      assert_field(exp["wrapper"], result.wrapper&.to_s, "wrapper", i, tc)
      assert_field(exp["reason"], result.reason, "reason", i, tc)
    end
  end

  def assert_field(expected, actual, name, i, tc)
    if expected.nil?
      assert_nil(actual, "case #{i} #{name}: #{tc['input'].inspect}")
    else
      assert_equal(expected, actual, "case #{i} #{name}: #{tc['input'].inspect}")
    end
  end

  test "wrapper? matches by host AND path, never a blanket google.* rule" do
    assert SearchUrl.wrapper?("https://www.google.com/url?q=https://example.com")
    assert SearchUrl.wrapper?("https://google.com/url")
    assert SearchUrl.wrapper?("https://google.com/goto?sig=x")
    assert SearchUrl.wrapper?("https://google.com/search?q=x")
    assert SearchUrl.wrapper?("https://news.google.com/articles/CBMiAmNo")
    assert SearchUrl.wrapper?("https://duckduckgo.com/l/?uddg=https://example.com")
    assert SearchUrl.wrapper?("https://vertexaisearch.cloud.google.com/grounding-api-redirect/AbC")

    # Direct Google publisher properties are NOT wrappers.
    refute SearchUrl.wrapper?("https://docs.google.com/document/d/abc/edit")
    refute SearchUrl.wrapper?("https://sites.google.com/view/site/home")
    refute SearchUrl.wrapper?("https://drive.google.com/file/d/abc/view")
    refute SearchUrl.wrapper?("https://example.com")
    refute SearchUrl.wrapper?("not a url")
    refute SearchUrl.wrapper?(nil)
    refute SearchUrl.wrapper?("")
  end

  test "never raises on junk input" do
    junk = [
      nil, "", "   ", "\n\t", "\x00\x01\x02", "%%%%", "://", "http://",
      "https://exa mple.com", "http://[::1]:99999/", "https://例え.テスト/ページ",
      "https://#{'a' * 2000}.com", "-", "HTTP/1.1 200 OK", "https://example.com:notaport/",
      ["array"], { "hash" => 1 }, 3.14, 42, true, Object.new
    ]
    junk.each do |j|
      assert_nothing_raised { SearchUrl.unwrap(j) }
      assert_nothing_raised { SearchUrl.wrapper?(j) }
    end
  end

  test "result is a frozen Data with the six interface fields" do
    %i[url host wrapped wrapper status reason].each do |member|
      assert SearchUrl::Result.members.include?(member)
    end
    CASES.each do |tc|
      assert SearchUrl.unwrap(tc["input"]).frozen?
    end
  end
end
