module PagyHelper
  include Pagy::Frontend

  # Custom Tailwind-styled pagination
  def pagy_tailwind_nav(pagy, **vars)
    # Don't render pagination if there's only one page
    return "" if pagy.pages <= 1

    html = +%(<nav class="flex items-center justify-between border-t border-gray-200 dark:border-gray-700 px-4 sm:px-0 mt-6" x-data @keydown.window.left="$el.querySelector('.pagy-prev')?.click()" @keydown.window.right="$el.querySelector('.pagy-next')?.click()">)

    # Previous button
    html << %(<div class="-mt-px flex w-0 flex-1">)
    if pagy.prev
      html << link_to(pagy_url_for(pagy, pagy.prev), class: "pagy-prev inline-flex items-center border-t-2 border-transparent pt-4 pr-1 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 hover:text-gray-700 dark:hover:text-gray-200") do
        %(<svg class="mr-3 size-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path fill-rule="evenodd" d="M18 10a.75.75 0 0 1-.75.75H4.66l2.1 1.95a.75.75 0 1 1-1.02 1.1l-3.5-3.25a.75.75 0 0 1 0-1.1l3.5-3.25a.75.75 0 1 1 1.02 1.1l-2.1 1.95h12.59A.75.75 0 0 1 18 10Z" clip-rule="evenodd" />
        </svg>
        Previous).html_safe
      end
    else
      html << %(<span class="inline-flex items-center border-t-2 border-transparent pt-4 pr-1 text-sm font-medium text-gray-300 dark:text-gray-600">
        <svg class="mr-3 size-5 text-gray-300 dark:text-gray-600" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path fill-rule="evenodd" d="M18 10a.75.75 0 0 1-.75.75H4.66l2.1 1.95a.75.75 0 1 1-1.02 1.1l-3.5-3.25a.75.75 0 0 1 0-1.1l3.5-3.25a.75.75 0 1 1 1.02 1.1l-2.1 1.95h12.59A.75.75 0 0 1 18 10Z" clip-rule="evenodd" />
        </svg>
        Previous
      </span>)
    end
    html << %(</div>)

    # Page links
    html << %(<div class="hidden md:-mt-px md:flex">)
    pagy.series(**vars).each do |item|
      if item.is_a?(Integer) # Page link (not current)
        html << link_to(item, pagy_url_for(pagy, item), class: "inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 hover:text-gray-700 dark:hover:text-gray-200")
      elsif item.is_a?(String) # Current page (String)
        html << %(<span class="inline-flex items-center border-t-2 border-blue-500 px-4 pt-4 text-sm font-medium text-blue-600 dark:text-blue-400" aria-current="page">#{item}</span>)
      elsif item == :gap # Gap
        html << %(<span class="inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 dark:text-gray-400">...</span>)
      end
    end
    html << %(</div>)

    # Next button
    html << %(<div class="-mt-px flex w-0 flex-1 justify-end">)
    if pagy.next
      html << link_to(pagy_url_for(pagy, pagy.next), class: "pagy-next inline-flex items-center border-t-2 border-transparent pt-4 pl-1 text-sm font-medium text-gray-500 dark:text-gray-400 hover:border-gray-300 hover:text-gray-700 dark:hover:text-gray-200") do
        %(Next
        <svg class="ml-3 size-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path fill-rule="evenodd" d="M2 10a.75.75 0 0 1 .75-.75h12.59l-2.1-1.95a.75.75 0 1 1 1.02-1.1l3.5 3.25a.75.75 0 0 1 0 1.1l-3.5 3.25a.75.75 0 1 1-1.02-1.1l2.1-1.95H2.75A.75.75 0 0 1 2 10Z" clip-rule="evenodd" />
        </svg>).html_safe
      end
    else
      html << %(<span class="inline-flex items-center border-t-2 border-transparent pt-4 pl-1 text-sm font-medium text-gray-300 dark:text-gray-600">
        Next
        <svg class="ml-3 size-5 text-gray-300 dark:text-gray-600" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path fill-rule="evenodd" d="M2 10a.75.75 0 0 1 .75-.75h12.59l-2.1-1.95a.75.75 0 1 1 1.02-1.1l3.5 3.25a.75.75 0 0 1 0 1.1l-3.5 3.25a.75.75 0 1 1-1.02-1.1l2.1-1.95H2.75A.75.75 0 0 1 2 10Z" clip-rule="evenodd" />
        </svg>
      </span>)
    end
    html << %(</div>)

    html << %(</nav>)
    html.html_safe
  end
end
