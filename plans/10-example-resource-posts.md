# Phase 10: Example Resource (Posts)

## Goal

Create a team-scoped CRUD resource (Posts) that demonstrates the full pattern: team ownership, pagination, rich text, file attachments, and the TailwindFormBuilder. This serves as a reference for adding new resources to the app.

## Steps

### 10.1 Generate Post Model

```bash
bin/rails generate model Post \
  title:string \
  team:references \
  created_by:references
```

Edit migration:
- `created_by` should reference `users`: `t.references :created_by, foreign_key: { to_table: :users }, null: true`
- Add index on `team_id`

Run `bin/rails db:migrate`.

### 10.2 Post Model

```ruby
class Post < ApplicationRecord
  belongs_to :team
  belongs_to :created_by, class_name: "User", optional: true

  has_rich_text :body
  has_one_attached :cover_image

  validates :title, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
end
```

### 10.3 Add posts association to Team

```ruby
# app/models/team.rb
has_many :posts, dependent: :destroy
```

### 10.4 PostsController

Create `app/controllers/posts_controller.rb`:

```ruby
class PostsController < ApplicationController
  include TeamScoped

  before_action :set_post, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @posts = pagy(Current.team.posts.newest_first, limit: 10)
  end

  def show
  end

  def new
    @post = Current.team.posts.build
  end

  def create
    @post = Current.team.posts.build(post_params)
    @post.created_by = current_user

    if @post.save
      redirect_to post_path(@post, team_id: Current.team.id), notice: "Post created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to post_path(@post, team_id: Current.team.id), notice: "Post updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy!
    redirect_to posts_path(team_id: Current.team.id), notice: "Post deleted."
  end

  private

  def set_post
    @post = Current.team.posts.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :body, :cover_image)
  end
end
```

### 10.5 Routes

Add inside the team scope:

```ruby
scope "/teams/:team_id", constraints: { team_id: /\d+/ } do
  resources :posts
  # ... existing settings routes ...
end
```

### 10.6 Views

#### Index (`app/views/posts/index.html.erb`)

```erb
<div class="flex items-center justify-between mb-8">
  <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">Posts</h1>
  <%= btn "New Post", href: new_post_path(team_id: Current.team.id), icon: "plus" %>
</div>

<% if @posts.any? %>
  <div class="space-y-4">
    <% @posts.each do |post| %>
      <div class="bg-white dark:bg-gray-900 shadow-sm ring-1 ring-gray-900/5 dark:ring-gray-100/10 sm:rounded-lg p-6">
        <div class="flex items-start justify-between">
          <div>
            <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
              <%= link_to post.title, post_path(post, team_id: Current.team.id),
                class: "hover:text-blue-600 dark:hover:text-blue-400" %>
            </h2>
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
              <%= post.created_by&.display_id %> · <%= time_tag_ago(post.created_at) %>
            </p>
          </div>
          <% if post.cover_image.attached? %>
            <%= image_tag post.cover_image.variant(resize_to_fill: [80, 80]),
              class: "w-20 h-20 rounded-lg object-cover" %>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>

  <%= pagy_tailwind_nav(@pagy) %>
<% else %>
  <div class="text-center py-12">
    <h3 class="text-sm font-semibold text-gray-900 dark:text-gray-100">No posts yet</h3>
    <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Get started by creating your first post.</p>
    <div class="mt-6">
      <%= btn "New Post", href: new_post_path(team_id: Current.team.id), icon: "plus" %>
    </div>
  </div>
<% end %>
```

#### Show (`app/views/posts/show.html.erb`)

```erb
<div class="max-w-4xl mx-auto">
  <div class="mb-6 flex items-center justify-between">
    <div>
      <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100"><%= @post.title %></h1>
      <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
        <%= @post.created_by&.display_id %> · <%= time_tag_ago(@post.created_at) %>
      </p>
    </div>
    <div class="flex gap-2">
      <%= btn "Edit", href: edit_post_path(@post, team_id: Current.team.id), icon: "pencil", outline: true %>
      <%= btn "Delete", url: post_path(@post, team_id: Current.team.id), method: :delete,
        icon: "trash", variant: :danger, outline: true,
        confirm: "Delete this post?", confirm_description: "This action cannot be undone." %>
    </div>
  </div>

  <% if @post.cover_image.attached? %>
    <div class="mb-8">
      <%= image_tag @post.cover_image, class: "w-full rounded-lg shadow-sm" %>
    </div>
  <% end %>

  <div class="prose dark:prose-invert max-w-none">
    <%= @post.body %>
  </div>
</div>
```

#### Form Partial (`app/views/posts/_form.html.erb`)

```erb
<%= tailwind_form_for(@post, url: url, method: method, data: { controller: nil }) do |f| %>
  <%= f.text_field :title, autofocus: true %>
  <%= f.rich_text_area :body, label: "Content" %>
  <%= f.file_field :cover_image, label: "Cover Image", preview: true,
    current_attachment: @post.cover_image, help: "Optional. Displayed at the top of the post." %>

  <div class="flex items-center gap-4 pt-4">
    <%= f.submit submit_text, icon: "check" %>
    <%= link_to "Cancel",
      (@post.persisted? ? post_path(@post, team_id: Current.team.id) : posts_path(team_id: Current.team.id)),
      class: "text-sm text-gray-600 hover:text-gray-500 dark:text-gray-400" %>
  </div>
<% end %>
```

#### New (`app/views/posts/new.html.erb`)

```erb
<div class="max-w-4xl mx-auto">
  <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-8">New Post</h1>
  <%= render "form", post: @post, url: posts_path(team_id: Current.team.id), method: :post, submit_text: "Create Post" %>
</div>
```

#### Edit (`app/views/posts/edit.html.erb`)

```erb
<div class="max-w-4xl mx-auto">
  <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-8">Edit Post</h1>
  <%= render "form", post: @post, url: post_path(@post, team_id: Current.team.id), method: :patch, submit_text: "Update Post" %>
</div>
```

### 10.7 Update Navigation

Update `_navigation.html.erb` to show "Posts" link for logged-in users (replacing or alongside the team-scoped pages link from Fileinbox):

```erb
<%= link_to posts_path(team_id: current_or_default_team.id),
  class: "flex items-center gap-x-2 text-sm/6 font-medium ..." do %>
  <%= icon "document-text", class: "size-5 text-gray-500" %>
  Posts
<% end %>
```

### 10.8 Update default_authenticated_path

In the Authentication concern:

```ruby
def default_authenticated_path
  if Current.user&.default_team
    posts_path(team_id: Current.user.default_team.id)
  else
    root_path
  end
end
```

## Verification

- Create a new post with title, rich text body, and cover image
- Post shows in the index with pagination
- Post detail page shows title, author, timestamp, cover image, rich text body
- Edit post works, including changing/removing the cover image
- Delete post works with confirmation dialog (uses our Alpine modal)
- Only team members can see team posts
- `time_tag_ago` shows "2 minutes ago" with full datetime on hover
- Pagy pagination renders correctly with Tailwind styling
- `copy_btn` can be used (e.g., copy post URL)

## Files Created/Modified

- `app/models/post.rb`
- `app/models/team.rb` (add `has_many :posts`)
- `app/controllers/posts_controller.rb`
- `app/views/posts/index.html.erb`
- `app/views/posts/show.html.erb`
- `app/views/posts/new.html.erb`
- `app/views/posts/edit.html.erb`
- `app/views/posts/_form.html.erb`
- `app/views/layouts/_navigation.html.erb` (update)
- `app/controllers/concerns/authentication.rb` (update default path)
- `config/routes.rb` (update)
- `db/migrate/*_create_posts.rb`
