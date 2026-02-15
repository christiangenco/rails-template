module ButtonHelper
  def btn(text = nil, **options, &block)
    text = capture(&block) if block_given?
    
    variant = options.delete(:variant) || :primary
    size = options.delete(:size) || :md
    outline = options.delete(:outline) || false
    icon = options.delete(:icon)
    right_icon = options.delete(:right_icon)
    disabled = options.delete(:disabled) || false
    confirm = options.delete(:confirm)
    href = options.delete(:href)
    method = options.delete(:method)
    url = options.delete(:url)
    
    # Build CSS classes
    classes = [
      "inline-flex items-center justify-center font-medium rounded-lg transition-colors",
      "focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-gray-900",
      btn_size_classes(size),
      outline ? outline_variant_classes(variant) : solid_variant_classes(variant),
      gap_classes(icon, right_icon, text),
      options.delete(:class)
    ].compact.join(" ")
    
    # Build content with icons
    content = "".html_safe
    content += icon(icon, class: btn_icon_size_class(size)) if icon
    content += text if text
    content += icon(right_icon, class: btn_icon_size_class(size)) if right_icon
    
    # Add data attributes
    data = options.delete(:data) || {}
    data[:turbo_confirm] = confirm if confirm
    options[:data] = data unless data.empty?
    
    # Render appropriate element
    if disabled
      options[:disabled] = true
      options[:class] = "#{classes} opacity-50 cursor-not-allowed"
      content_tag(:button, content, **options)
    elsif href
      options[:class] = classes
      link_to(content, href, **options)
    elsif method && url
      options[:class] = classes
      button_to(content, url, method: method, **options)
    else
      options[:class] = classes
      options[:type] ||= "button"
      content_tag(:button, content, **options)
    end
  end
  
  private
  
  def btn_size_classes(size)
    case size
    when :xs then "px-2.5 py-1.5 text-xs"
    when :sm then "px-3 py-2 text-sm"
    when :md then "px-4 py-2.5 text-sm"
    when :lg then "px-5 py-3 text-base"
    else "px-4 py-2.5 text-sm"
    end
  end
  
  def solid_variant_classes(variant)
    case variant
    when :primary
      "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500 dark:bg-blue-500 dark:hover:bg-blue-600"
    when :danger
      "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500 dark:bg-red-500 dark:hover:bg-red-600"
    when :success
      "bg-green-600 text-white hover:bg-green-700 focus:ring-green-500 dark:bg-green-500 dark:hover:bg-green-600"
    when :warning
      "bg-yellow-600 text-white hover:bg-yellow-700 focus:ring-yellow-500 dark:bg-yellow-500 dark:hover:bg-yellow-600"
    else
      "bg-gray-600 text-white hover:bg-gray-700 focus:ring-gray-500 dark:bg-gray-500 dark:hover:bg-gray-600"
    end
  end
  
  def outline_variant_classes(variant)
    case variant
    when :primary
      "border border-blue-600 text-blue-600 hover:bg-blue-50 focus:ring-blue-500 dark:border-blue-400 dark:text-blue-400 dark:hover:bg-blue-950"
    when :danger
      "border border-red-600 text-red-600 hover:bg-red-50 focus:ring-red-500 dark:border-red-400 dark:text-red-400 dark:hover:bg-red-950"
    when :success
      "border border-green-600 text-green-600 hover:bg-green-50 focus:ring-green-500 dark:border-green-400 dark:text-green-400 dark:hover:bg-green-950"
    when :warning
      "border border-yellow-600 text-yellow-600 hover:bg-yellow-50 focus:ring-yellow-500 dark:border-yellow-400 dark:text-yellow-400 dark:hover:bg-yellow-950"
    else
      "border border-gray-600 text-gray-600 hover:bg-gray-50 focus:ring-gray-500 dark:border-gray-400 dark:text-gray-400 dark:hover:bg-gray-950"
    end
  end
  
  def gap_classes(icon, right_icon, text)
    return nil unless text && (icon || right_icon)
    "gap-2"
  end
  
  def btn_icon_size_class(size)
    case size
    when :xs then "size-3"
    when :sm then "size-4"
    when :md then "size-5"
    when :lg then "size-6"
    else "size-5"
    end
  end
end
