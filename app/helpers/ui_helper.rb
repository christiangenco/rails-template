module UiHelper
  def pill(text, variant: :gray, **options)
    variant_classes = case variant
    when :primary
      "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
    when :success
      "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
    when :danger
      "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
    when :warning
      "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200"
    when :gray
      "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200"
    else
      "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200"
    end

    classes = [
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      variant_classes,
      options.delete(:class)
    ].compact.join(" ")

    content_tag(:span, text, class: classes, **options)
  end

  def heading(text, level: 1, **options)
    classes = case level
    when 1
      "text-3xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-4xl"
    when 2
      "text-2xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-3xl"
    when 3
      "text-xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-2xl"
    when 4
      "text-lg font-semibold text-gray-900 dark:text-gray-100"
    when 5
      "text-base font-semibold text-gray-900 dark:text-gray-100"
    when 6
      "text-sm font-semibold text-gray-900 dark:text-gray-100"
    else
      "text-base font-semibold text-gray-900 dark:text-gray-100"
    end

    classes = [ classes, options.delete(:class) ].compact.join(" ")
    content_tag("h#{level}".to_sym, text, class: classes, **options)
  end

  def h1(text, **options)
    heading(text, level: 1, **options)
  end

  def h2(text, **options)
    heading(text, level: 2, **options)
  end

  def h3(text, **options)
    heading(text, level: 3, **options)
  end

  def h4(text, **options)
    heading(text, level: 4, **options)
  end

  def h5(text, **options)
    heading(text, level: 5, **options)
  end

  def h6(text, **options)
    heading(text, level: 6, **options)
  end

  # --- Airtable-style filterable/sortable table headers (see plan 14) ---

  # Sort-only header cell. Clicking toggles asc/desc on sort_key via URL params.
  def sortable_th(label, sort_key, align: :left)
    current_sort = params[:sort]
    current_dir = params[:dir]
    is_active = current_sort == sort_key

    new_dir = (is_active && current_dir != "desc") ? "desc" : "asc"

    arrow = if is_active
      current_dir == "desc" ? " ↓" : " ↑"
    else
      ""
    end

    align_class = align == :right ? "text-right" : "text-left"
    active_class = is_active ? "text-gray-900 dark:text-gray-100" : "text-gray-500 dark:text-gray-400"

    url = url_for(request.query_parameters.merge(sort: sort_key, dir: new_dir))

    content_tag(:th, class: "px-4 py-3 #{align_class} text-xs font-medium uppercase tracking-wider #{active_class}") do
      link_to("#{label}#{arrow}".html_safe, url, class: "hover:text-gray-900 dark:hover:text-gray-100 group")
    end
  end

  # Filterable header cell with sort controls + a type-specific filter dropdown.
  # `model` defaults to @filterable_model; column config (type, enum values) is
  # read from the model's Filterable declaration when available.
  def filterable_th(label, sort_key, column: nil, type: :text, values: nil, align: :left, model: nil)
    model ||= @filterable_model
    column = (column || sort_key).to_s
    col_config = model&.respond_to?(:filter_columns) ? (model.filter_columns[column] || {}) : {}
    type = (col_config[:type] || type).to_sym

    values ||= enum_filter_values_for(model, column) if type == :enum && model

    align_class = align == :right ? "text-right" : "text-left"

    content_tag(:th, class: "px-4 py-3 #{align_class} text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400 relative whitespace-nowrap") do
      render "shared/filterable_th",
             label: label,
             sort_key: sort_key,
             column: column,
             type: type,
             values: values || []
    end
  end

  # URL with a single filter (filter_key/op) removed, preserving other params.
  def url_for_removing_filter(filter_key, op = nil)
    query = request.query_parameters.deep_dup
    filters = query["f"]
    return url_for(query.except("page")) unless filters.is_a?(Hash)

    if filter_key.blank?
      query.delete("f")
    elsif op.present? && filters[filter_key].is_a?(Hash)
      filters[filter_key].delete(op.to_s)
      filters.delete(filter_key) if filters[filter_key].blank?
    else
      filters.delete(filter_key)
    end

    query.delete("f") if filters.blank?
    query.delete("page")
    url_for(query)
  end

  # Human-readable label for a filter operator.
  def filter_op_label(op)
    {
      "eq" => "is",
      "neq" => "is not",
      "in" => "in",
      "not_in" => "not in",
      "gte" => "≥",
      "lte" => "≤",
      "between" => "between",
      "contains" => "contains",
      "starts_with" => "starts with",
      "is_empty" => "is empty",
      "is_not_empty" => "is not empty"
    }[op.to_s] || op.to_s
  end

  # Human-readable label for a filter's value (resolves enum value labels and
  # formats date values).
  def filter_value_label(filter, value_labels = nil)
    val = filter[:value]
    case filter[:op]
    when "is_empty", "is_not_empty"
      ""
    when "in", "not_in"
      parts = val.split(",").map(&:strip)
      parts = parts.map { |p| value_labels&.dig(p) || p }
      parts.join(", ")
    else
      return filter_date_label(val) if filter[:type] == :date
      value_labels&.dig(val) || val
    end
  end

  # Format an ISO-8601 date filter value as "Jun 11, 2026"; pass through on
  # anything unparseable.
  def filter_date_label(val)
    Date.iso8601(val.to_s).strftime("%b %-d, %Y")
  rescue ArgumentError, TypeError
    val
  end

  private

  # Enum filter values for a column: enum keys (humanized) when the column is a
  # Rails enum, otherwise the distinct non-blank values present in the table.
  def enum_filter_values_for(model, column)
    @filterable_enum_values ||= {}
    cache_key = "#{model.name}:#{column}"
    return @filterable_enum_values[cache_key] if @filterable_enum_values.key?(cache_key)

    if model.defined_enums[column.to_s]
      @filterable_enum_values[cache_key] = model.defined_enums[column.to_s].keys.map do |k|
        { "value" => k, "label" => k.humanize }
      end
    else
      @filterable_enum_values[cache_key] = model
        .where.not(column => [ nil, "" ])
        .distinct
        .order(column)
        .pluck(column)
        .map(&:to_s)
    end
  rescue StandardError
    @filterable_enum_values[cache_key] = []
  end
end
