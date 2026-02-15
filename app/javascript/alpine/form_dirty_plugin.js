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
