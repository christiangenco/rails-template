xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "MyApp Blog"
    xml.description "Articles and updates from MyApp"
    xml.link articles_url

    @articles.first(20).each do |article|
      xml.item do
        xml.title article.title
        xml.description article.description
        xml.link article_url(article)
        xml.pubDate article.published_at&.to_time&.rfc822
      end
    end
  end
end
