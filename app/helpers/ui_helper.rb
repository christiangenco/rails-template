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
    
    classes = [classes, options.delete(:class)].compact.join(" ")
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
end
