# Plan 14: Add Airtable-Style Filterable Columns to Rails Template

## Context

Digi (digi.gxb.vc) has a great Airtable-style column filtering system where clicking any table header opens a dropdown with sort controls and type-specific filters (text search, enum checkboxes, number ranges). This should be built into the rails-template as default infrastructure so every new project gets it for free.

## What to Add

### 1. Filterable Concern (`app/models/concerns/filterable.rb`)

Port from digi. Provides:
- `filterable :column, type: :text/:enum/:number, label: "Label"` — DSL for declaring filterable columns on any model
- `Model.apply_filters(scope, params[:f])` — applies `f[col][op]=value` URL params to AR scope
- `Model.active_filters_from(params[:f])` — returns array of active filter descriptions for pill UI
- Operators: enum (eq/neq/in/not_in), number (eq/gte/lte/between), text (contains/starts_with/eq/is_empty/is_not_empty)

### 2. FiltersFromParams Controller Concern (`app/controllers/concerns/filters_from_params.rb`)

Port from digi. Provides:
- `apply_url_filters(scope)` — applies `params[:f]` to any AR scope whose model includes Filterable
- `apply_url_sorting(scope, sort_map, default_sort:, default_dir:)` — applies `params[:sort]`/`params[:dir]` using a column mapping

### 3. Alpine.js Column Filter Component (`app/javascript/alpine/column_filter.js`)

Port from digi. Handles:
- Dropdown open/close with click-outside dismiss
- URL building from filter state (no form submission — Turbo.visit)
- Sort direction toggle
- Type-specific filter UIs (enum search + checkboxes, number min/max, text operator + value)

### 4. Filterable TH Partial (`app/views/shared/_filterable_th.html.erb`)

Port from digi. Server-renders:
- Sort arrow indicators
- Active filter dot
- Dropdown with sort/filter controls (type-specific)

### 5. Filter Pills Partial (`app/views/shared/_filter_pills.html.erb`)

Port from digi. Shows active filter tags with remove buttons and "Clear all" link.

### 6. UI Helper Methods

Add to `app/helpers/ui_helper.rb` (or `application_helper.rb`):
- `filterable_th(label, sort_key, column:, type:, values:, align:, model:)` — renders filterable th
- `sortable_th(label, sort_key, align:)` — simpler sort-only th (for non-filterable columns)
- `url_for_removing_filter(filter_key, op)` — URL with specific filter removed
- `filter_op_label(op)` — human label for filter operator
- `filter_value_label(filter)` — human label for filter value

### 7. Tests

- `test/models/concerns/filterable_test.rb` — unit tests for apply_filters and active_filters_from
- Integration test showing a model with `include Filterable` + controller using `FiltersFromParams`

## Source Files to Copy From

All from `~/projects/digi`:
- `app/models/concerns/filterable.rb`
- `app/controllers/concerns/filters_from_params.rb`
- `app/javascript/alpine/column_filter.js`
- `app/views/shared/_filterable_th.html.erb`
- `app/views/shared/_filter_pills.html.erb`
- `app/helpers/ui_helper.rb` (the `filterable_th`, `sortable_th`, filter helper methods)
- `test/models/concerns/filterable_test.rb`

## Usage Example (for template README)

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  include Filterable
  filterable :name,     type: :text,   label: "Name"
  filterable :category, type: :enum,   label: "Category"
  filterable :price,    type: :number, label: "Price"
end

# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  include FiltersFromParams

  def index
    @filterable_model = Product
    scope = apply_url_filters(Product.all)
    scope = apply_url_sorting(scope, { "name" => :name, "price" => :price }, default_sort: "name")
    @pagy, @products = pagy(scope, limit: 50)
  end
end
```

```erb
<%# app/views/products/index.html.erb %>
<table>
  <thead>
    <tr>
      <%%= filterable_th "Name", "name", column: "name" %>
      <%%= filterable_th "Category", "cat", column: "category" %>
      <%%= filterable_th "Price", "price", column: "price", align: :right %>
    </tr>
    <%%= render "shared/filter_pills", model: Product, clear_path: products_path, colspan: 3 %>
  </thead>
  ...
</table>
```

## Implementation Steps

1. Copy the 7 source files listed above into the template
2. Register `column_filter.js` in `app/javascript/application.js`
3. Add the helper methods to the template's helper file
4. Write tests
5. Update the template README to document the pattern
6. Commit
