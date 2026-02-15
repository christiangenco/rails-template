# Phase 3: Alpine.js + Turbo

## Goal

Set up Alpine.js as the JavaScript framework (instead of Stimulus), with the Turbo adapter so Alpine plays nicely with Turbo Drive page navigations. Include the modal system and Turbo confirm override.

## Steps

### 3.1 Remove Stimulus (if present)

Delete any Stimulus-related files that may have been generated:

```bash
rm -rf app/javascript/controllers/
```

Remove from `config/importmap.rb` any stimulus pins.

### 3.2 Pin Alpine.js packages

```bash
bin/importmap pin alpinejs
bin/importmap pin alpine-turbo-drive-adapter
bin/importmap pin @alpinejs/collapse
```

Verify `config/importmap.rb` has:

```ruby
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "alpinejs"
pin "alpine-turbo-drive-adapter"
pin "@alpinejs/collapse", to: "@alpinejs--collapse.js"

pin_all_from "app/javascript/alpine", under: "alpine"
pin_all_from "app/javascript/utils", under: "utils"
```

### 3.3 Create app/javascript/application.js

```javascript
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
```

### 3.4 Create app/javascript/utils/showModal.js

This creates an Alpine store that powers a global modal dialog.

```javascript
import Alpine from "alpinejs"

Alpine.store("modal", {
  isOpen: false,
  title: "",
  description: "",
  buttonText: "",
  theme: "primary",
  resolve: null,

  show({ title, description, buttonText, theme = "primary" }) {
    this.title = title
    this.description = description
    this.buttonText = buttonText
    this.theme = theme
    this.isOpen = true

    return new Promise((resolve) => {
      this.resolve = resolve
    })
  },

  confirm() {
    this.isOpen = false
    if (this.resolve) {
      this.resolve(true)
      this.resolve = null
    }
  },

  cancel() {
    this.isOpen = false
    if (this.resolve) {
      this.resolve(false)
      this.resolve = null
    }
  },
})

export default function showModal(options) {
  return Alpine.store("modal").show(options)
}
```

### 3.5 Create app/javascript/utils/turbo_confirm.js

Overrides Turbo's default `window.confirm` with our Alpine modal for `data-turbo-confirm` attributes.

```javascript
Turbo.config.forms.confirm = async (message, formElement, submitter) => {
  if (typeof window.showModal === "function") {
    const description =
      submitter?.dataset?.dataConfirmDescription ||
      "This action cannot be undone."
    return window.showModal({
      title: message,
      buttonText: submitter?.textContent?.trim() || "Confirm",
      description: description,
      theme: "danger",
    })
  }
  return window.confirm(message)
}
```

### 3.6 Create app/javascript/alpine/form_dirty_plugin.js

Tracks form changes and exposes a reactive `dirty` property. Used with `x-data="formDirty"` on forms.

```javascript
/**
 * Alpine.js Form Dirty Tracking
 *
 * Usage:
 *   <form x-data="formDirty">                    - Basic dirty tracking
 *   <form x-data="formDirty({ warn: true })">   - Also warn on navigation
 *
 * Inside the form:
 *   x-show="dirty"    - Boolean: is form dirty?
 *   @click="reset()"  - Reset baseline to current state
 */

function serializeForm(form) {
  const data = {}
  const formData = new FormData(form)

  for (let [name, value] of formData.entries()) {
    if (value instanceof File) {
      value = { name: value.name, size: value.size, type: value.type, lastModified: value.lastModified }
    }
    if (name in data) {
      if (!Array.isArray(data[name])) data[name] = [data[name]]
      data[name].push(value)
    } else {
      data[name] = value
    }
  }

  return JSON.stringify(data)
}

document.addEventListener("alpine:init", () => {
  Alpine.data("formDirty", (options = {}) => ({
    dirty: false,
    _baseline: null,
    _form: null,
    _debounceTimeout: null,
    _beforeUnloadHandler: null,
    _turboBeforeVisitHandler: null,

    init() {
      this._form = this.$el
      setTimeout(() => {
        this._baseline = serializeForm(this._form)
        this.dirty = false
      }, 100)

      this._form.addEventListener("input", () => this._debouncedCheck())
      this._form.addEventListener("change", () => this._debouncedCheck())

      this._form.addEventListener("turbo:submit-end", (event) => {
        if (event.detail.success) this.reset()
      })

      if (options.warn) this._setupNavigationWarnings()
    },

    _debouncedCheck() {
      if (this._debounceTimeout) clearTimeout(this._debounceTimeout)
      this._debounceTimeout = setTimeout(() => this._checkDirty(), 50)
    },

    _checkDirty() {
      if (!this._baseline) return
      const current = serializeForm(this._form)
      this.dirty = current !== this._baseline
    },

    reset() {
      this._baseline = serializeForm(this._form)
      this.dirty = false
    },

    _setupNavigationWarnings() {
      this._beforeUnloadHandler = (event) => {
        if (!this.dirty) return
        event.preventDefault()
        event.returnValue = ""
      }
      window.addEventListener("beforeunload", this._beforeUnloadHandler)

      this._turboBeforeVisitHandler = (event) => {
        if (!this.dirty) return
        if (event.target.closest("turbo-frame")) return
        event.preventDefault()
        window.showModal({
          title: "Unsaved changes",
          description: "You have unsaved changes. Are you sure you want to leave?",
          buttonText: "Leave without saving",
          theme: "danger",
        }).then((confirmed) => {
          if (confirmed) {
            this.dirty = false
            Turbo.visit(event.detail.url)
          }
        })
      }
      document.addEventListener("turbo:before-visit", this._turboBeforeVisitHandler)
    },

    destroy() {
      if (this._beforeUnloadHandler) window.removeEventListener("beforeunload", this._beforeUnloadHandler)
      if (this._turboBeforeVisitHandler) document.removeEventListener("turbo:before-visit", this._turboBeforeVisitHandler)
    },
  }))
})
```

### 3.7 Create directory structure

```bash
mkdir -p app/javascript/alpine
mkdir -p app/javascript/utils
```

## Verification

- `bin/rails server` starts, no JS errors in browser console
- Alpine.js initializes (add `<div x-data="{ open: false }"><button @click="open = !open">Toggle</button><p x-show="open">Hello</p></div>` to a view and verify it works)
- Turbo Drive navigations don't break Alpine components
- `window.showModal` is available in the browser console

## Files Created/Modified

- `config/importmap.rb`
- `app/javascript/application.js`
- `app/javascript/utils/showModal.js`
- `app/javascript/utils/turbo_confirm.js`
- `app/javascript/alpine/form_dirty_plugin.js`
- Removed: `app/javascript/controllers/` (Stimulus)
