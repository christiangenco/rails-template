import "@hotwired/turbo-rails"

import "alpine-turbo-drive-adapter"
import Alpine from "alpinejs"
import collapse from "@alpinejs/collapse"
Alpine.plugin(collapse)
window.Alpine = Alpine

// Alpine plugins & components
import "alpine/form_dirty_plugin"

Alpine.start()

// Modal system (must be after Alpine.start since it uses Alpine.store)
import showModal from "utils/showModal"
window.showModal = showModal

// Override Turbo's confirm with our Alpine modal
import "utils/turbo_confirm"

import "trix"
import "@rails/actiontext"
