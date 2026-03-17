// Auto-resize all textareas to fit their content.
// Works with Turbo (listens for turbo:load and turbo:frame-load).

function autoResize(textarea) {
  textarea.style.overflow = "hidden"
  textarea.style.height = "auto"
  textarea.style.height = textarea.scrollHeight + "px"
}

function initTextareas(root = document) {
  root.querySelectorAll("textarea:not([data-no-auto-resize])").forEach((ta) => {
    if (ta._autoResizeBound) return
    ta._autoResizeBound = true
    ta.style.overflow = "hidden"
    ta.addEventListener("input", () => autoResize(ta))
    // Initial sizing (use rAF to ensure layout is ready)
    requestAnimationFrame(() => autoResize(ta))
  })
}

// On initial load
document.addEventListener("DOMContentLoaded", () => initTextareas())

// Turbo navigations
document.addEventListener("turbo:load", () => initTextareas())
document.addEventListener("turbo:frame-load", (e) => initTextareas(e.target))

// Turbo stream morphs / appends
document.addEventListener("turbo:before-stream-render", (e) => {
  const original = e.detail.render
  e.detail.render = async function (streamElement) {
    await original(streamElement)
    requestAnimationFrame(() => initTextareas())
  }
})
