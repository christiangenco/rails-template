# Phase 4: UI Helpers & Layouts

## Goal

Port the reusable UI helpers (buttons, copy-to-clipboard, pills, headings, time tags, form builder, pagination) and set up the application layout with navigation, flash messages, modal, and footer.

## Steps

### 4.1 ButtonHelper

Create `app/helpers/button_helper.rb` — ported from Fileinbox.

Provides `btn(text, **options)` helper with:
- **Variants**: `:primary`, `:danger`, `:success`, `:warning`
- **Sizes**: `:xs`, `:sm`, `:md`, `:lg`
- **Outline mode**: `outline: true`
- **Icons**: `icon:` (left), `right_icon:` (right) — uses `rails_icons` gem
- **Rendering as**: regular `<button>`, `<a>` link (via `href:`), or `button_to` form (via `method:` + `url:`)
- **Disabled state**: `disabled: true`
- **Confirm dialogs**: `confirm:` text triggers `data-turbo-confirm`
- **Block mode**: `btn { "Custom content" }`
- Full dark mode support on all variants

Port the complete implementation including all private methods: `size_classes`, `solid_variant_classes`, `outline_variant_classes`, `gap_classes`, `icon_size_class`.

### 4.2 CopyHelper

Create `app/helpers/copy_helper.rb` — ported from Fileinbox.

Provides `copy_btn(value, **options)` helper with:
- Alpine-powered clipboard copy with visual feedback
- Options: `text:`, `copied_text:`, `icon:`, `copied_icon:`, `icon_only:`, `duration:`, `from:` (CSS selector), `plain:`
- Uses `navigator.clipboard.writeText`
- Shows "Copied!" feedback with configurable duration

### 4.3 UiHelper

Create `app/helpers/ui_helper.rb` — ported from Fileinbox.

Provides:
- `pill(text, variant:)` — badge/pill component
- `heading(text, level:)` — styled headings
- `h1` through `h6` — convenience methods
- All with dark mode support

### 4.4 TimeHelper

Create `app/helpers/time_helper.rb` — ported from Fileinbox.

Provides `time_tag_ago(datetime)`:
- Renders `<time datetime="..." title="February 15, 2026 8:43 AM CST">about 2 hours ago</time>`
- Uses Rails' built-in `time_ago_in_words`
- Full datetime on hover via `title` attribute
- Returns "—" for nil datetimes

```ruby
module TimeHelper
  def time_tag_ago(datetime)
    return "—" if datetime.nil?

    time_tag datetime, "#{time_ago_in_words(datetime)} ago",
      title: datetime.strftime("%B %-d, %Y %-l:%M %p %Z")
  end
end
```

### 4.5 TailwindFormBuilder

Create `app/helpers/tailwind_form_builder.rb` — ported from Fileinbox.

Custom `ActionView::Helpers::FormBuilder` subclass with Tailwind-styled:
- `text_field`, `email_field`, `url_field`, `password_field`, `number_field`, `date_field`
- `text_area` with auto-height
- `select` and `collection_select` with custom chevron
- `check_box` with SVG checkmark overlay
- `radio_button` with custom dot
- `file_field` with optional image preview (Alpine-powered)
- `color_field`
- `submit` — delegates to `btn` helper
- `form_group` with title/description
- `input` — generic method that infers type from field name

All fields support:
- `label:` text (or `false` to hide)
- `help:` text below the field
- `wrapper_options:` for the outer div
- `leading_icon:` / `trailing_icon:` for text inputs
- `addon:` for input group addons
- Error state with red outline, error icon, and error message

All with full dark mode support.

### 4.6 PagyHelper

Create `app/helpers/pagy_helper.rb` with a custom Tailwind-styled pagination nav.

```ruby
module PagyHelper
  include Pagy::Frontend

  def pagy_tailwind_nav(pagy, **vars)
    return "" if pagy.pages <= 1
    # ... (port the full implementation from Fileinbox)
    # Tailwind-styled Previous/Next + page number links
    # Keyboard navigation: left/right arrow keys via Alpine x-data
  end
end
```

Also create `config/initializers/pagy.rb`:

```ruby
require "pagy/extras/overflow"

Pagy::DEFAULT.merge!(
  limit: 25,
  size: 7,
  overflow: :last_page
)
```

### 4.7 ApplicationHelper

Create `app/helpers/application_helper.rb` that:
- Includes `Pagy::Frontend`, `ButtonHelper`, `CopyHelper`, `UiHelper`, `TimeHelper`
- Provides `tailwind_form_for` and `tailwind_form_with` that set `builder: TailwindFormBuilder`
- Provides `gravatar_url(email, size:)`
- Provides `current_or_default_team` (returns `Current.team || current_user&.default_team`)
- Provides `team_switch_path(team)` for the team switcher
- Provides `admin?` check

### 4.8 Application Layout

Create `app/views/layouts/application.html.erb`:

```erb
<!DOCTYPE html>
<html lang="en" class="h-full bg-white dark:bg-gray-950">
  <head>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= render "layouts/meta" %>

    <%# Three-way dark mode toggle — prevent FOUC %>
    <script>
      document.documentElement.classList.toggle(
        "dark",
        localStorage.theme === "dark" ||
          (!("theme" in localStorage) && window.matchMedia("(prefers-color-scheme: dark)").matches)
      );
    </script>

    <%= stylesheet_link_tag :tailwind, "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag :application, "data-turbo-track": "reload" %>

    <script async src="https://ga.jspm.io/npm:es-module-shims@1.8.2/dist/es-module-shims.js" data-turbo-track="reload"></script>
    <%= javascript_importmap_tags %>

    <meta name="view-transition" content="same-origin">
    <%= yield(:head) %>
  </head>
  <body class="h-full bg-white dark:bg-gray-950 text-gray-900 dark:text-gray-100">
    <%= render "layouts/navigation" %>
    <%= render "layouts/messages" %>

    <div class="min-h-[75vh] mt-6">
      <%= yield(:naked) %>
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <%= yield %>
      </div>
    </div>

    <div class="mt-6">
      <%= render "layouts/footer" %>
    </div>

    <%= render "layouts/modal" %>
  </body>
</html>
```

### 4.9 Meta Tags Partial

Create `app/views/layouts/_meta.html.erb` with:
- Standard meta charset, viewport
- Favicon links (placeholder)
- `<title>` with `content_for(:title)` fallback
- `<meta name="description">` with `content_for(:description)` fallback
- Canonical URL (if set)
- Open Graph tags (title, description, type, url, image)
- Twitter Card tags
- Article-specific OG tags (published_time, modified_time)
- JSON-LD structured data slot
- RSS feed discovery link

### 4.10 Navigation Partial

Create `app/views/layouts/_navigation.html.erb` — simplified from Fileinbox:

**Logged out state:**
- Logo on left
- Login button with arrow icon on right
- Mobile hamburger menu

**Logged in state:**
- Logo + nav links (Posts) on left
- Team switcher dropdown (if user has multiple teams)
- Dark mode toggle (light/dark/auto cycle)
- Account dropdown on right: Profile, Team Settings, Team Members, Sign Out
- Mobile hamburger with all the above

The dark mode toggle cycles through three states using `localStorage.theme`:
- Auto (computer-desktop icon) — respects OS preference
- Light (sun icon) — forces light
- Dark (moon icon) — forces dark

### 4.11 Flash Messages Partial

Create `app/views/layouts/_messages.html.erb` — ported from Fileinbox.

Toast notifications in the top-right corner:
- Uses `turbo_frame_tag :flash` for Turbo updates
- Alpine transitions (slide in, fade out)
- Auto-dismiss after 5 seconds
- Green check icon for `notice`, red warning icon for `alert`
- Dismiss button

### 4.12 Modal Partial

Create `app/views/layouts/_modal.html.erb` — ported from Fileinbox.

Alpine store-driven modal dialog:
- Driven by `$store.modal` (set up in `showModal.js`)
- Supports themes: primary (blue), success (green), warning (yellow), danger (red)
- Each theme shows a matching icon
- Confirm and Cancel buttons
- Escape key dismisses
- Click-outside dismisses
- Used by the Turbo confirm override for `data-turbo-confirm`

### 4.13 Footer Partial

Create `app/views/layouts/_footer.html.erb` — minimal placeholder:

```erb
<footer class="bg-gray-50 dark:bg-gray-900">
  <div class="mx-auto max-w-7xl px-6 py-12 text-center text-sm text-gray-500 dark:text-gray-400">
    <p>&copy; <%= Date.current.year %> MyApp. All rights reserved.</p>
  </div>
</footer>
```

### 4.14 Public Layout

Create `app/views/layouts/public.html.erb` — minimal layout for auth pages:

Same `<head>` as application layout but body is centered with logo at top, no navigation bar, no footer. Used for login/signup pages.

### 4.15 Horizontal Tabs Partial

Create `app/views/shared/_horizontal_tabs.html.erb` — ported from Fileinbox.

Reusable tab navigation:
- Desktop: horizontal tabs with bottom border indicator
- Mobile: dropdown select
- Accepts `tabs:` array of `{ label:, path:, icon: }` hashes
- Highlights current tab based on `current_path:`

### 4.16 rails_icons Configuration

Configure `rails_icons` gem for Heroicons:

```bash
bin/rails generate rails_icons:initializer
```

Configure to use Heroicons (outline variant by default). This provides the `icon "name"` helper used throughout.

## Verification

- Render a test page with `btn`, `copy_btn`, `pill`, `h1`, `time_tag_ago`
- Render a form with `tailwind_form_for` and verify all field types
- Navigation shows login button when logged out
- Flash messages appear and auto-dismiss
- Modal can be triggered from browser console: `showModal({ title: "Test", buttonText: "OK", theme: "primary" })`
- Dark mode toggle cycles through three states
- Horizontal tabs render correctly on desktop and mobile

## Files Created/Modified

- `app/helpers/button_helper.rb`
- `app/helpers/copy_helper.rb`
- `app/helpers/ui_helper.rb`
- `app/helpers/time_helper.rb`
- `app/helpers/pagy_helper.rb`
- `app/helpers/tailwind_form_builder.rb`
- `app/helpers/application_helper.rb`
- `config/initializers/pagy.rb`
- `app/views/layouts/application.html.erb`
- `app/views/layouts/public.html.erb`
- `app/views/layouts/_meta.html.erb`
- `app/views/layouts/_navigation.html.erb`
- `app/views/layouts/_messages.html.erb`
- `app/views/layouts/_modal.html.erb`
- `app/views/layouts/_footer.html.erb`
- `app/views/shared/_horizontal_tabs.html.erb`
- `config/initializers/rails_icons.rb`
