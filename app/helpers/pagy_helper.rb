module PagyHelper
  include Pagy::Frontend

  def pagy_tailwind_nav(pagy, **vars)
    return "" if pagy.pages <= 1
    
    link_classes = "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 focus:z-20"
    active_classes = "relative z-10 inline-flex items-center px-4 py-2 text-sm font-semibold text-white bg-blue-600 dark:bg-blue-500 focus:z-20"
    disabled_classes = "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-400 dark:text-gray-600 cursor-not-allowed"
    gap_classes = "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-400"
    
    # Alpine keyboard navigation
    content_tag(:nav, 
      class: "flex items-center justify-between border-t border-gray-200 dark:border-gray-800 px-4 sm:px-0 mt-6",
      "aria-label": "Pagination",
      "x-data": "{}",
      "@keydown.left.window": pagy.prev ? "window.location.href = '#{pagy_url_for(pagy, pagy.prev, **vars)}'" : nil,
      "@keydown.right.window": pagy.next ? "window.location.href = '#{pagy_url_for(pagy, pagy.next, **vars)}'" : nil
    ) do
      # Previous button
      prev_button = if pagy.prev
        link_to(
          pagy_url_for(pagy, pagy.prev, **vars),
          class: "relative inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 rounded-lg"
        ) do
          icon("arrow-left", class: "size-5") + 
          content_tag(:span, "Previous")
        end
      else
        content_tag(:span, 
          class: "relative inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-400 dark:text-gray-600 cursor-not-allowed rounded-lg"
        ) do
          icon("arrow-left", class: "size-5") + 
          content_tag(:span, "Previous")
        end
      end
      
      # Page numbers
      page_links = content_tag(:div, class: "hidden md:flex md:flex-1 md:items-center md:justify-center") do
        content_tag(:div, class: "isolate inline-flex -space-x-px rounded-lg shadow-sm") do
          pagy.series.map do |item|
            case item
            when Integer
              if item == pagy.page
                content_tag(:span, item, class: active_classes)
              else
                link_to(item, pagy_url_for(pagy, item, **vars), class: link_classes)
              end
            when String
              content_tag(:span, item, class: gap_classes)
            when :gap
              content_tag(:span, "…", class: gap_classes)
            end
          end.join.html_safe
        end
      end
      
      # Next button
      next_button = if pagy.next
        link_to(
          pagy_url_for(pagy, pagy.next, **vars),
          class: "relative inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 rounded-lg"
        ) do
          content_tag(:span, "Next") + 
          icon("arrow-right", class: "size-5")
        end
      else
        content_tag(:span, 
          class: "relative inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-400 dark:text-gray-600 cursor-not-allowed rounded-lg"
        ) do
          content_tag(:span, "Next") + 
          icon("arrow-right", class: "size-5")
        end
      end
      
      prev_button + page_links + next_button
    end
  end
end
