# Phase 11: Landing Page & Articles

## Goal

Create an example marketing landing page for the homepage (shown to logged-out users) and a file-based static article system styled with Tailwind Typography. This gives a complete starting point for SEO content and marketing.

## Steps

### 11.1 HomeController

Create `app/controllers/home_controller.rb`:

```ruby
class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    if current_user
      redirect_to posts_path(team_id: current_user.default_team&.id)
      return
    end

    render "index"
  end
end
```

### 11.2 Landing Page View

Create `app/views/home/index.html.erb` with a full example marketing page using Tailwind.

The page should be rendered in a `content_for(:naked)` block (full-width, no container padding), since marketing sections typically span the full viewport.

Sections to include:

#### Hero Section
- Large heading: "Build something amazing"
- Subtitle paragraph explaining the product
- CTA button (links to `/session/new`)
- Clean gradient or subtle background

```erb
<% content_for :title, "MyApp — Build Something Amazing" %>
<% content_for :description, "MyApp helps teams collaborate and ship faster. Start for free." %>

<% content_for :naked do %>
  <!-- Hero -->
  <div class="bg-white dark:bg-gray-950">
    <div class="mx-auto max-w-2xl px-6 py-24 sm:py-32 lg:px-8 text-center">
      <h1 class="text-4xl font-semibold tracking-tight text-balance text-gray-900 dark:text-gray-100 sm:text-6xl">
        Build something amazing
      </h1>
      <p class="mt-8 text-lg text-gray-600 dark:text-gray-300 text-pretty sm:text-xl/8">
        MyApp helps teams collaborate, organize, and ship faster. Start for free — no credit card required.
      </p>
      <div class="mt-10 flex items-center justify-center gap-x-6">
        <%= btn "Get started", href: new_session_path, size: :lg, icon: "arrow-right" %>
        <%= link_to "Learn more →", "#features",
          class: "text-sm/6 font-semibold text-gray-900 dark:text-gray-100" %>
      </div>
    </div>
  </div>

  <!-- Features -->
  ...

  <!-- Testimonials -->
  ...

  <!-- FAQ -->
  ...

  <!-- CTA -->
  ...
<% end %>
```

#### Features Section
- "Features" heading with subtitle
- 3-column grid (responsive) with icon + title + description for each feature
- Use Heroicons via `icon` helper
- Example features: "Team Collaboration", "Rich Text Editor", "Secure by Default", etc.

#### Testimonials Section
- 2-3 fake testimonials in a grid
- Each with quote text, avatar (gravatar or placeholder), name, and title

#### FAQ Section
- "Frequently Asked Questions" heading
- 2-3 column grid of Q&A pairs
- Plain text, no accordion needed (simple is better for SEO)

#### Bottom CTA Section
- "Ready to get started?" heading
- Subtitle
- CTA button

### 11.3 Article Model (PORO)

Create `app/models/article.rb` — a Plain Old Ruby Object (not ActiveRecord) that reads static article files from the filesystem.

```ruby
class Article
  include ActiveModel::Model

  attr_accessor :slug, :title, :description, :og_image, :published_at, :updated_at,
                :author, :keywords, :canonical_url, :robots, :og_type

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
```

### 11.4 ArticlesController

Create `app/controllers/articles_controller.rb`:

```ruby
class ArticlesController < ApplicationController
  allow_unauthenticated_access

  def index
    @articles = Article.published
  end

  def show
    @article = Article.find(params[:id])
  end
end
```

### 11.5 Article Views

#### Index (`app/views/articles/index.html.erb`)

Lists published articles:
- Title, author, description
- Optional OG image thumbnail
- Link to article detail page

```erb
<div class="mx-auto max-w-7xl py-8">
  <header class="mb-8">
    <h1 class="text-3xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-4xl">Articles</h1>
  </header>

  <div class="space-y-8">
    <% @articles.each do |article| %>
      <article class="flex flex-col sm:flex-row gap-6 pb-8 border-b border-gray-200 dark:border-gray-800">
        <% if article.og_image.present? %>
          <div class="sm:w-48 sm:flex-shrink-0">
            <%= link_to article.path do %>
              <%= image_tag article.og_image, alt: article.title,
                class: "w-full h-32 sm:h-full object-cover rounded-lg shadow-sm hover:shadow-md transition-shadow" %>
            <% end %>
          </div>
        <% end %>
        <div class="flex-1">
          <h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-2">
            <%= link_to article.title, article.path, class: "hover:text-blue-600 transition-colors" %>
          </h2>
          <% if article.author %>
            <p class="text-sm text-gray-600 dark:text-gray-300 mb-3"><%= article.author %></p>
          <% end %>
          <% if article.description.present? %>
            <p class="text-gray-600 dark:text-gray-300"><%= article.description %></p>
          <% end %>
        </div>
      </article>
    <% end %>
  </div>

  <% if @articles.empty? %>
    <p class="text-center py-12 text-gray-500 dark:text-gray-400">No articles yet.</p>
  <% end %>
</div>
```

#### Show (`app/views/articles/show.html.erb`)

Renders the article content wrapped in Tailwind Typography `prose` classes:

```erb
<% content_for :title, "#{@article.title} | MyApp" %>

<div class="mx-auto max-w-4xl py-8">
  <header class="mb-8 prose lg:prose-xl dark:prose-invert mx-auto">
    <h1><%= @article.title %></h1>
    <% if @article.author %>
      <p class="text-gray-600 dark:text-gray-300"><%= @article.author %></p>
    <% end %>
  </header>

  <article class="prose lg:prose-xl dark:prose-invert mx-auto">
    <%= render inline: @article.body, type: :erb %>
  </article>

  <footer class="mt-12 pt-8 border-t border-gray-200 dark:border-gray-800">
    <%= link_to "← Back to articles", articles_path,
      class: "text-blue-600 dark:text-blue-400 hover:text-blue-800 font-medium" %>
  </footer>
</div>
```

### 11.6 Example Article

Create `app/views/articles/content/getting-started.html.erb`:

```erb
---
title: "Getting Started with MyApp"
description: "Learn how to set up your workspace, invite your team, and create your first post."
author: "MyApp Team"
published_at: 2026-01-15
og_image: ""
---

<p>Welcome to MyApp! This guide will walk you through setting up your account and getting productive in minutes.</p>

<h2>Creating Your Account</h2>

<p>To get started, visit the <a href="/session/new">sign-in page</a> and enter your email address. We'll send you a 6-digit code — no password needed.</p>

<h2>Setting Up Your Team</h2>

<p>When you sign up, we automatically create a personal workspace for you. You can rename it from <strong>Team Settings → General</strong>.</p>

<p>To invite team members, go to <strong>Team Settings → Team</strong> and add their email addresses. They'll receive an invitation to join.</p>

<h2>Creating Your First Post</h2>

<p>Navigate to <strong>Posts</strong> and click <strong>New Post</strong>. Give it a title, write some content using the rich text editor, and optionally add a cover image.</p>

<h2>What's Next?</h2>

<ul>
  <li>Explore the team settings to customize your workspace</li>
  <li>Update your profile name from the Profile page</li>
  <li>Try the dark mode toggle in the navigation bar</li>
</ul>

<p>That's it! You're ready to build something amazing. 🚀</p>
```

This article demonstrates:
- YAML front matter with title, description, author, published_at
- Standard HTML rendered inside `prose` container
- Links, headings, lists, bold text — all styled by `@tailwindcss/typography`

### 11.7 Routes

```ruby
root to: "home#index"

resources :articles, path: "a", only: [:index, :show]
```

### 11.8 Add Articles to Navigation

In the logged-out navigation, add an "Articles" link alongside "Login":

```erb
<%= link_to "Articles", articles_path,
  class: "text-sm/6 font-semibold text-gray-900 dark:text-gray-100" %>
```

### 11.9 RSS Feed (optional but nice)

Create `app/views/articles/index.rss.builder`:

```ruby
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
```

Add to ArticlesController:
```ruby
def index
  @articles = Article.published
  respond_to do |format|
    format.html
    format.rss { render layout: false }
  end
end
```

Add feed route:
```ruby
resources :articles, path: "a", only: [:index, :show] do
  collection do
    get :index, defaults: { format: :rss }, as: :feed, action: :index, constraints: { format: :rss }
  end
end
```

And add RSS discovery to `_meta.html.erb`:
```erb
<link rel="alternate" type="application/rss+xml" title="MyApp Blog" href="<%= articles_url(format: :rss) %>">
```

## Verification

- Visit `/` while logged out — see the landing page with hero, features, testimonials, FAQ
- Visit `/` while logged in — redirect to posts
- Visit `/a` — see the articles index with the "Getting Started" article
- Visit `/a/getting-started` — see the full article styled with Tailwind Typography
- Article renders headings, paragraphs, links, lists, bold text correctly
- Dark mode works on all marketing pages
- Meta tags (title, description, OG) are set correctly for articles
- RSS feed works at `/a.rss`

## Files Created/Modified

- `app/controllers/home_controller.rb`
- `app/controllers/articles_controller.rb`
- `app/models/article.rb`
- `app/views/home/index.html.erb`
- `app/views/articles/index.html.erb`
- `app/views/articles/show.html.erb`
- `app/views/articles/content/getting-started.html.erb`
- `app/views/layouts/_navigation.html.erb` (update)
- `app/views/layouts/_meta.html.erb` (RSS discovery)
- `config/routes.rb` (update)
