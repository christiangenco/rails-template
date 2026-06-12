/**
 * Column filter dropdown — handles filter form state and URL building.
 * Display state (sort arrows, active dots) is server-rendered.
 * This only manages the dropdown interaction + navigation on apply/sort.
 */
document.addEventListener("alpine:init", () => {
  Alpine.data("columnFilter", ({ column, type, sortKey, values = [] }) => ({
    open: false,
    search: "",
    values,
    selectedValues: [],
    minValue: "",
    maxValue: "",
    dateFrom: "",
    dateTo: "",
    textOp: "contains",
    textValue: "",
    panelTop: 0,
    panelLeft: 0,
    _closeOnScroll: null,

    toggle() {
      if (this.open) {
        this.open = false
        return
      }
      this._positionPanel()
      this.open = true
      this._closeOnScroll = () => { this.open = false }
      window.addEventListener("scroll", this._closeOnScroll, { capture: true, once: true })
    },

    _positionPanel() {
      const rect = this.$refs.trigger.getBoundingClientRect()
      const panelWidth = 256 // w-64
      const margin = 8
      let left = rect.left
      if (left + panelWidth > window.innerWidth - margin) {
        left = Math.max(margin, window.innerWidth - panelWidth - margin)
      }
      this.panelTop = rect.bottom + 4
      this.panelLeft = left
    },

    init() {
      this.$watch("open", value => {
        if (!value && this._closeOnScroll) {
          window.removeEventListener("scroll", this._closeOnScroll, { capture: true })
          this._closeOnScroll = null
        }
      })
      const params = new URL(window.location.href).searchParams
      if (type === "enum") {
        const v = params.get(`f[${column}][in]`)
        this.selectedValues = v ? v.split(",").filter(Boolean) : []
      } else if (type === "number") {
        this.minValue = params.get(`f[${column}][gte]`) || ""
        this.maxValue = params.get(`f[${column}][lte]`) || ""
      } else if (type === "date") {
        this.dateFrom = params.get(`f[${column}][gte]`) || ""
        this.dateTo = params.get(`f[${column}][lte]`) || ""
      } else {
        for (const op of ["contains", "starts_with", "eq", "is_empty", "is_not_empty"]) {
          if (params.has(`f[${column}][${op}]`)) {
            this.textOp = op
            this.textValue = params.get(`f[${column}][${op}]`) || ""
            break
          }
        }
      }
    },

    get filteredEnumValues() {
      if (!this.search) return this.values
      const s = this.search.toLowerCase()
      return this.values.filter(v => String(v.label ?? v).toLowerCase().includes(s))
    },

    applySort(dir) {
      this._navigate(url => {
        url.searchParams.set("sort", sortKey)
        url.searchParams.set("dir", dir)
      })
    },

    applyFilter() {
      this._navigate(url => {
        this._clearParams(url)
        if (type === "enum" && this.selectedValues.length > 0) {
          url.searchParams.set(`f[${column}][in]`, this.selectedValues.join(","))
        } else if (type === "number") {
          if (this.minValue !== "") url.searchParams.set(`f[${column}][gte]`, this.minValue)
          if (this.maxValue !== "") url.searchParams.set(`f[${column}][lte]`, this.maxValue)
        } else if (type === "date") {
          if (this.dateFrom !== "") url.searchParams.set(`f[${column}][gte]`, this.dateFrom)
          if (this.dateTo !== "") url.searchParams.set(`f[${column}][lte]`, this.dateTo)
        } else if (type === "text") {
          if (["is_empty", "is_not_empty"].includes(this.textOp)) {
            url.searchParams.set(`f[${column}][${this.textOp}]`, "")
          } else if (this.textValue !== "") {
            url.searchParams.set(`f[${column}][${this.textOp}]`, this.textValue)
          }
        }
      })
    },

    clearFilter() {
      this._navigate(url => this._clearParams(url))
    },

    _clearParams(url) {
      for (const key of [...url.searchParams.keys()]) {
        if (key.startsWith(`f[${column}]`)) url.searchParams.delete(key)
      }
    },

    _navigate(mutate) {
      const url = new URL(window.location.href)
      mutate(url)
      url.searchParams.delete("page")
      this.open = false
      Turbo.visit(url.toString())
    }
  }))
})
