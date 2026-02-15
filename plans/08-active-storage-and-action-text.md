# Phase 8: Active Storage & Action Text

## Goal

Set up Active Storage for file uploads and Action Text with Trix for rich text editing. These will be used by the example Post resource in Phase 10.

## Steps

### 8.1 Install Active Storage

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

This creates the `active_storage_blobs`, `active_storage_attachments`, and `active_storage_variant_records` tables.

### 8.2 Configure Active Storage

In `config/storage.yml`:

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

In `config/environments/development.rb`:
```ruby
config.active_storage.service = :local
```

In `config/environments/production.rb`:
```ruby
config.active_storage.service = :local  # Or :amazon, :google, etc.
```

Note: For production, you'll likely want to switch to S3 or similar. The template defaults to local disk storage (backed up via Litestream for the database, but actual files live on the volume mounted at `/rails/storage`).

### 8.3 Install Action Text

```bash
bin/rails action_text:install
bin/rails db:migrate
```

This:
- Creates the `action_text_rich_texts` table
- Adds Trix editor JavaScript and CSS
- Creates `app/views/layouts/action_text/contents/_content.html.erb`

### 8.4 Configure Trix Styling

The default Trix stylesheet may conflict with Tailwind. Create or update `app/views/layouts/action_text/contents/_content.html.erb`:

```erb
<div class="trix-content prose dark:prose-invert max-w-none">
  <%= yield %>
</div>
```

This wraps Action Text output in Tailwind's `prose` class for consistent typography styling.

### 8.5 Add Trix to importmap

Action Text's installer should have added:

```ruby
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
```

In `app/javascript/application.js`, ensure these are imported:

```javascript
import "trix"
import "@rails/actiontext"
```

### 8.6 Style Trix Editor

Add some basic styling to `app/assets/stylesheets/application.css` to make Trix look good with Tailwind:

```css
/* Trix editor styling */
trix-editor {
  min-height: 12rem;
}

trix-editor.trix-content {
  overflow-y: auto;
}
```

The form builder's rich text area will use the standard Rails `rich_text_area` helper, which renders the Trix editor.

### 8.7 Add image_processing gem

Already in Gemfile from Phase 1. This enables Active Storage image variants (thumbnails, resizing, etc.).

Ensure `libvips` is available (it will be in the Dockerfile in Phase 12):

```ruby
# config/application.rb
config.active_storage.variant_processor = :vips
```

### 8.8 Add TailwindFormBuilder support for rich_text_area

Add a `rich_text_area` method to `TailwindFormBuilder`:

```ruby
def rich_text_area(method, options = {})
  render_field(method, options) do |field_options|
    # Use ActionText's rich_text_area helper
    @template.rich_text_area(object_name, method,
      field_options.except(:label, :label_options, :help, :wrapper_options)
    )
  end
end
```

This wraps the Trix editor with the same label/help/error treatment as other form fields.

## Verification

- `bin/rails db:migrate` runs clean with Active Storage and Action Text tables
- Trix editor renders in a form with `f.rich_text_area :body`
- Can type rich text, bold, italic, links, etc.
- Can upload images into the Trix editor (attached via Active Storage)
- Rich text content renders correctly with `prose` styling
- File attachments work via `has_one_attached :image` on a model

## Files Created/Modified

- `db/migrate/*_create_active_storage_tables.rb` (generated)
- `db/migrate/*_create_action_text_tables.rb` (generated)
- `config/storage.yml`
- `config/environments/development.rb` (update)
- `config/environments/production.rb` (update)
- `config/application.rb` (vips processor)
- `config/importmap.rb` (trix pins)
- `app/javascript/application.js` (add trix/actiontext imports)
- `app/assets/stylesheets/application.css` (trix styles)
- `app/views/layouts/action_text/contents/_content.html.erb`
- `app/helpers/tailwind_form_builder.rb` (add rich_text_area)
