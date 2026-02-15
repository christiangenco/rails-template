class Article
  include ActiveModel::Model

  attr_accessor :slug, :title, :description, :og_image, :published_at, :updated_at,
                :author, :keywords, :canonical_url, :robots, :og_type, :unlisted

  class << self
    def all
      load_articles
    end

    def published
      all.select { |a| a.published? && !a.unlisted }
        .sort_by(&:published_at).reverse
    end

    def find(slug)
      article = all.find { |a| a.slug == slug }
      raise ActiveRecord::RecordNotFound, "Article not found: #{slug}" unless article
      article
    end

    private

    def load_articles
      articles_path = Rails.root.join("app", "views", "articles", "content")
      return [] unless Dir.exist?(articles_path)
      
      Dir.glob(articles_path.join("*.html.erb")).filter_map do |file|
        filename = File.basename(file, ".html.erb")
        metadata = extract_metadata(file)

        new(
          slug: filename,
          title: metadata[:title] || filename.humanize.titleize,
          description: metadata[:description],
          og_image: metadata[:og_image],
          published_at: parse_date(metadata[:published_at]),
          updated_at: parse_date(metadata[:updated_at]),
          author: metadata[:author],
          unlisted: metadata[:unlisted]
        )
      end
    end

    def extract_metadata(file_path)
      content = File.read(file_path)
      if content =~ /\A---\s*\n(.*?)\n---\s*\n/m
        YAML.safe_load($1, permitted_classes: [Date, Time], symbolize_names: true) || {}
      else
        {}
      end
    end

    def parse_date(val)
      return nil unless val
      return val if val.is_a?(Date)
      Date.parse(val.to_s)
    rescue Date::Error
      nil
    end
  end

  def published?
    published_at.present? && published_at <= Date.current
  end

  def to_param = slug

  def path
    Rails.application.routes.url_helpers.article_path(slug)
  end

  def body
    return "" unless File.exist?(file_path)
    raw = File.read(file_path)
    content = raw.sub(/\A---\s*\n.*?\n---\s*\n/m, "").strip
    content.html_safe
  end

  def file_path
    Rails.root.join("app", "views", "articles", "content", "#{slug}.html.erb")
  end

  def excerpt(length = 160)
    description.presence || ""
  end

  def published_at_iso8601
    published_at&.iso8601
  end

  def updated_at_iso8601
    updated_at&.iso8601
  end

  def og_type
    @og_type || "article"
  end
end
