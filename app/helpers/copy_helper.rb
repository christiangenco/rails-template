module CopyHelper
  def copy_btn(value, **options)
    text = options.delete(:text) || "Copy"
    copied_text = options.delete(:copied_text) || "Copied!"
    icon = options.delete(:icon) || "clipboard-document"
    copied_icon = options.delete(:copied_icon) || "clipboard-document-check"
    icon_only = options.delete(:icon_only) || false
    duration = options.delete(:duration) || 2000
    from = options.delete(:from)
    plain = options.delete(:plain) || false
    
    # Build Alpine x-data
    if from
      copy_action = "navigator.clipboard.writeText(document.querySelector('#{from}').textContent.trim())"
    else
      escaped_value = value.to_s.gsub("'", "\\\\'")
      copy_action = "navigator.clipboard.writeText('#{escaped_value}')"
    end
    
    alpine_data = {
      copied: false,
      copy: "#{copy_action}; copied = true; setTimeout(() => copied = false, #{duration})"
    }
    
    # Build button content
    content = if icon_only
      # Show only icons, swap on copy
      <<~HTML.html_safe
        <span x-show="!copied">#{icon(icon, class: "size-5")}</span>
        <span x-show="copied" x-cloak>#{icon(copied_icon, class: "size-5")}</span>
      HTML
    else
      # Show text + icon
      <<~HTML.html_safe
        <span x-show="!copied" class="inline-flex items-center gap-2">
          #{icon(icon, class: "size-5")}
          <span>#{text}</span>
        </span>
        <span x-show="copied" x-cloak class="inline-flex items-center gap-2">
          #{icon(copied_icon, class: "size-5")}
          <span>#{copied_text}</span>
        </span>
      HTML
    end
    
    if plain
      # Plain button without btn styling
      btn_class = options.delete(:class) || "inline-flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
      content_tag(
        :button,
        content,
        type: "button",
        class: btn_class,
        "x-data": alpine_data.to_json,
        "@click": "copy",
        **options
      )
    else
      # Use btn helper
      variant = options.delete(:variant) || :primary
      size = options.delete(:size) || :sm
      
      content_tag(
        :button,
        content,
        type: "button",
        class: [
          "inline-flex items-center justify-center font-medium rounded-lg transition-colors",
          "focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-gray-900",
          copy_btn_size_classes(size, variant),
          options.delete(:class)
        ].compact.join(" "),
        "x-data": alpine_data.to_json,
        "@click": "copy",
        **options
      )
    end
  end
  
  private
  
  def copy_btn_size_classes(size, variant)
    base = case size
    when :xs then "px-2.5 py-1.5 text-xs"
    when :sm then "px-3 py-2 text-sm"
    when :md then "px-4 py-2.5 text-sm"
    when :lg then "px-5 py-3 text-base"
    else "px-3 py-2 text-sm"
    end
    
    color = case variant
    when :primary
      "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500 dark:bg-blue-500 dark:hover:bg-blue-600"
    when :danger
      "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500 dark:bg-red-500 dark:hover:bg-red-600"
    when :success
      "bg-green-600 text-white hover:bg-green-700 focus:ring-green-500 dark:bg-green-500 dark:hover:bg-green-600"
    else
      "bg-gray-600 text-white hover:bg-gray-700 focus:ring-gray-500 dark:bg-gray-500 dark:hover:bg-gray-600"
    end
    
    "#{base} #{color}"
  end
end
