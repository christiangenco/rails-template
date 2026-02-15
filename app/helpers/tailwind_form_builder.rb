class TailwindFormBuilder < ActionView::Helpers::FormBuilder
  INPUT_CLASSES = "block w-full rounded-lg border-0 py-2 px-3 text-gray-900 dark:text-gray-100 bg-white dark:bg-gray-900 ring-1 ring-inset ring-gray-300 dark:ring-gray-700 placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:ring-2 focus:ring-inset focus:ring-blue-600 dark:focus:ring-blue-500 sm:text-sm sm:leading-6"
  ERROR_CLASSES = "ring-red-600 dark:ring-red-500 focus:ring-red-600 dark:focus:ring-red-500"
  
  # Text input fields
  def text_field(method, **options)
    render_text_field(method, **options) { |opts| super(method, **opts) }
  end
  
  def email_field(method, **options)
    render_text_field(method, **options) { |opts| super(method, **opts) }
  end
  
  def url_field(method, **options)
    render_text_field(method, **options) { |opts| super(method, **opts) }
  end
  
  def password_field(method, **options)
    render_text_field(method, **options) { |opts| super(method, **opts) }
  end
  
  def number_field(method, **options)
    render_text_field(method, **options) { |opts| super(method, **opts) }
  end
  
  def date_field(method, **options)
    render_text_field(method, **options) { |opts| super(method, **opts) }
  end
  
  def text_area(method, **options)
    label_text = options.delete(:label)
    help_text = options.delete(:help)
    wrapper_options = options.delete(:wrapper_options) || {}
    
    render_field_wrapper(method, label_text, help_text, wrapper_options) do
      options[:class] = build_classes(method, options[:class], textarea: true)
      options[:rows] ||= 4
      
      # Alpine auto-height
      options[:"x-data"] = "{}"
      options[:"x-init"] = "$el.style.height = $el.scrollHeight + 'px'"
      options[:"@input"] = "$el.style.height = 'auto'; $el.style.height = $el.scrollHeight + 'px'"
      
      super(method, **options)
    end
  end
  
  def select(method, choices = nil, select_options = {}, **options, &block)
    label_text = options.delete(:label)
    help_text = options.delete(:help)
    wrapper_options = options.delete(:wrapper_options) || {}
    
    render_field_wrapper(method, label_text, help_text, wrapper_options) do
      options[:class] = build_classes(method, options[:class], select: true)
      super(method, choices, select_options, **options, &block)
    end
  end
  
  def collection_select(method, collection, value_method, text_method, select_options = {}, **options)
    label_text = options.delete(:label)
    help_text = options.delete(:help)
    wrapper_options = options.delete(:wrapper_options) || {}
    
    render_field_wrapper(method, label_text, help_text, wrapper_options) do
      options[:class] = build_classes(method, options[:class], select: true)
      super(method, collection, value_method, text_method, select_options, **options)
    end
  end
  
  def check_box(method, **options)
    label_text = options.delete(:label)
    help_text = options.delete(:help)
    wrapper_options = options.delete(:wrapper_options) || {}
    checked_value = options.delete(:checked_value) || "1"
    unchecked_value = options.delete(:unchecked_value) || "0"
    
    wrapper_class = ["flex items-start gap-3", wrapper_options.delete(:class)].compact.join(" ")
    
    @template.content_tag(:div, class: wrapper_class, **wrapper_options) do
      checkbox_html = @template.content_tag(:div, class: "flex items-center h-6") do
        @template.content_tag(:div, class: "relative") do
          options[:class] = "size-4 rounded border-gray-300 dark:border-gray-700 text-blue-600 focus:ring-blue-600 dark:focus:ring-blue-500 bg-white dark:bg-gray-900"
          super(method, options, checked_value, unchecked_value)
        end
      end
      
      label_html = if label_text != false
        @template.content_tag(:div, class: "flex-1") do
          label_content = @template.content_tag(:label, class: "text-sm font-medium text-gray-900 dark:text-gray-100") do
            label_text || method.to_s.humanize
          end
          
          if help_text
            label_content + @template.content_tag(:p, help_text, class: "text-sm text-gray-500 dark:text-gray-400")
          else
            label_content
          end
        end
      end
      
      checkbox_html + (label_html || "".html_safe)
    end
  end
  
  def radio_button(method, tag_value, **options)
    label_text = options.delete(:label)
    help_text = options.delete(:help)
    wrapper_options = options.delete(:wrapper_options) || {}
    
    wrapper_class = ["flex items-start gap-3", wrapper_options.delete(:class)].compact.join(" ")
    
    @template.content_tag(:div, class: wrapper_class, **wrapper_options) do
      radio_html = @template.content_tag(:div, class: "flex items-center h-6") do
        options[:class] = "size-4 border-gray-300 dark:border-gray-700 text-blue-600 focus:ring-blue-600 dark:focus:ring-blue-500 bg-white dark:bg-gray-900"
        super(method, tag_value, **options)
      end
      
      label_html = if label_text != false
        @template.content_tag(:div, class: "flex-1") do
          label_content = @template.content_tag(:label, class: "text-sm font-medium text-gray-900 dark:text-gray-100") do
            label_text || tag_value.to_s.humanize
          end
          
          if help_text
            label_content + @template.content_tag(:p, help_text, class: "text-sm text-gray-500 dark:text-gray-400")
          else
            label_content
          end
        end
      end
      
      radio_html + (label_html || "".html_safe)
    end
  end
  
  def file_field(method, **options)
    label_text = options.delete(:label)
    help_text = options.delete(:help)
    wrapper_options = options.delete(:wrapper_options) || {}
    preview = options.delete(:preview) || false
    
    render_field_wrapper(method, label_text, help_text, wrapper_options) do
      options[:class] = "block w-full text-sm text-gray-900 dark:text-gray-100 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-medium file:bg-blue-50 dark:file:bg-blue-950 file:text-blue-700 dark:file:text-blue-300 hover:file:bg-blue-100 dark:hover:file:bg-blue-900"
      
      field = super(method, **options)
      
      if preview
        preview_html = @template.content_tag(:div, 
          "x-data": "{ preview: null }",
          "@change": "const file = $event.target.files[0]; if (file && file.type.startsWith('image/')) { const reader = new FileReader(); reader.onload = e => preview = e.target.result; reader.readAsDataURL(file); } else { preview = null; }"
        ) do
          field_html = field
          preview_img = @template.content_tag(:img, nil, 
            "x-show": "preview",
            ":src": "preview",
            class: "mt-4 max-w-xs rounded-lg",
            "x-cloak": true
          )
          field_html + preview_img
        end
        preview_html
      else
        field
      end
    end
  end
  
  def color_field(method, **options)
    label_text = options.delete(:label)
    help_text = options.delete(:help)
    wrapper_options = options.delete(:wrapper_options) || {}
    
    render_field_wrapper(method, label_text, help_text, wrapper_options) do
      options[:class] = "block h-10 w-20 rounded-lg border-0 ring-1 ring-inset ring-gray-300 dark:ring-gray-700"
      super(method, **options)
    end
  end
  
  def rich_text_area(method, **options)
    label_text = options.delete(:label)
    help_text = options.delete(:help)
    wrapper_options = options.delete(:wrapper_options) || {}
    
    render_field_wrapper(method, label_text, help_text, wrapper_options) do
      # Use ActionText's rich_text_area helper
      @template.rich_text_area(@object_name, method,
        options.except(:label, :help, :wrapper_options)
      )
    end
  end
  
  def submit(value = nil, **options)
    variant = options.delete(:variant) || :primary
    size = options.delete(:size) || :md
    icon = options.delete(:icon)
    
    @template.btn(value || "Submit", variant: variant, size: size, icon: icon, type: "submit", **options)
  end
  
  def form_group(title: nil, description: nil, **options, &block)
    @template.content_tag(:div, class: "space-y-4", **options) do
      header = if title || description
        @template.content_tag(:div) do
          title_html = title ? @template.content_tag(:h3, title, class: "text-base font-semibold text-gray-900 dark:text-gray-100") : "".html_safe
          desc_html = description ? @template.content_tag(:p, description, class: "mt-1 text-sm text-gray-500 dark:text-gray-400") : "".html_safe
          title_html + desc_html
        end
      else
        "".html_safe
      end
      
      header + @template.capture(&block)
    end
  end
  
  def input(method, **options)
    type = options.delete(:as) || infer_type(method)
    
    case type
    when :text then text_field(method, **options)
    when :email then email_field(method, **options)
    when :url then url_field(method, **options)
    when :password then password_field(method, **options)
    when :number then number_field(method, **options)
    when :date then date_field(method, **options)
    when :text_area then text_area(method, **options)
    when :rich_text_area then rich_text_area(method, **options)
    when :select then select(method, options.delete(:collection), **options)
    when :check_box then check_box(method, **options)
    when :file then file_field(method, **options)
    when :color then color_field(method, **options)
    else text_field(method, **options)
    end
  end
  
  private
  
  def render_text_field(method, **options, &block)
    label_text = options.delete(:label)
    help_text = options.delete(:help)
    wrapper_options = options.delete(:wrapper_options) || {}
    leading_icon = options.delete(:leading_icon)
    trailing_icon = options.delete(:trailing_icon)
    addon = options.delete(:addon)
    
    render_field_wrapper(method, label_text, help_text, wrapper_options) do
      if leading_icon || trailing_icon || addon
        render_input_group(method, leading_icon, trailing_icon, addon, options, &block)
      else
        options[:class] = build_classes(method, options[:class])
        block.call(options)
      end
    end
  end
  
  def render_field_wrapper(method, label_text, help_text, wrapper_options, &block)
    wrapper_class = [wrapper_options.delete(:class)].compact.join(" ")
    
    @template.content_tag(:div, class: wrapper_class, **wrapper_options) do
      label_html = if label_text != false
        label(method, label_text || method.to_s.humanize, class: "block text-sm font-medium text-gray-900 dark:text-gray-100 mb-2")
      else
        "".html_safe
      end
      
      field_html = block.call
      
      error_html = if @object && @object.errors[method].any?
        @template.content_tag(:p, @object.errors[method].first, class: "mt-2 text-sm text-red-600 dark:text-red-400")
      else
        "".html_safe
      end
      
      help_html = if help_text && (!@object || @object.errors[method].empty?)
        @template.content_tag(:p, help_text, class: "mt-2 text-sm text-gray-500 dark:text-gray-400")
      else
        "".html_safe
      end
      
      label_html + field_html + error_html + help_html
    end
  end
  
  def render_input_group(method, leading_icon, trailing_icon, addon, options, &block)
    @template.content_tag(:div, class: "relative") do
      leading_html = if leading_icon
        @template.content_tag(:div, class: "pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3") do
          @template.icon(leading_icon, class: "size-5 text-gray-400")
        end
      else
        "".html_safe
      end
      
      trailing_html = if trailing_icon
        @template.content_tag(:div, class: "pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3") do
          @template.icon(trailing_icon, class: "size-5 text-gray-400")
        end
      elsif @object && @object.errors[method].any?
        @template.content_tag(:div, class: "pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3") do
          @template.icon("exclamation-circle", class: "size-5 text-red-500")
        end
      else
        "".html_safe
      end
      
      addon_html = if addon
        @template.content_tag(:div, class: "pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3") do
          @template.content_tag(:span, addon, class: "text-gray-500 dark:text-gray-400 sm:text-sm")
        end
      else
        "".html_safe
      end
      
      options[:class] = build_classes(method, options[:class])
      options[:class] += " pl-10" if leading_icon
      options[:class] += " pr-10" if trailing_icon || addon || (@object && @object.errors[method].any?)
      
      field_html = block.call(options)
      
      leading_html + field_html + trailing_html + addon_html
    end
  end
  
  def build_classes(method, custom_class = nil, textarea: false, select: false)
    base = if textarea
      "block w-full rounded-lg border-0 py-2 px-3 text-gray-900 dark:text-gray-100 bg-white dark:bg-gray-900 ring-1 ring-inset ring-gray-300 dark:ring-gray-700 placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:ring-2 focus:ring-inset focus:ring-blue-600 dark:focus:ring-blue-500 sm:text-sm sm:leading-6 resize-none"
    elsif select
      "block w-full rounded-lg border-0 py-2 pl-3 pr-10 text-gray-900 dark:text-gray-100 bg-white dark:bg-gray-900 ring-1 ring-inset ring-gray-300 dark:ring-gray-700 focus:ring-2 focus:ring-inset focus:ring-blue-600 dark:focus:ring-blue-500 sm:text-sm sm:leading-6 appearance-none bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9Im5vbmUiIHZpZXdCb3g9IjAgMCAyMCAyMCI+PHBhdGggc3Ryb2tlPSIjNmI3MjgwIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIHN0cm9rZS13aWR0aD0iMS41IiBkPSJtNiA4IDQgNCA0LTQiLz48L3N2Zz4=')] dark:bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9Im5vbmUiIHZpZXdCb3g9IjAgMCAyMCAyMCI+PHBhdGggc3Ryb2tlPSIjOWNhM2FmIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIHN0cm9rZS13aWR0aD0iMS41IiBkPSJtNiA4IDQgNCA0LTQiLz48L3N2Zz4=')] bg-[length:1.25rem] bg-[right_0.5rem_center] bg-no-repeat"
    else
      INPUT_CLASSES
    end
    
    error = if @object && @object.errors[method].any?
      ERROR_CLASSES
    else
      ""
    end
    
    [base, error, custom_class].compact.join(" ")
  end
  
  def infer_type(method)
    method_str = method.to_s
    return :email if method_str.include?("email")
    return :url if method_str.include?("url") || method_str.include?("website")
    return :password if method_str.include?("password")
    return :number if method_str.include?("count") || method_str.include?("amount")
    return :date if method_str.include?("date") || method_str.include?("_at") || method_str.include?("_on")
    return :text_area if method_str.include?("description") || method_str.include?("content") || method_str.include?("body")
    :text
  end
end
