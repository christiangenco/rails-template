// Preserve Alpine.js-managed attributes across Turbo morph refreshes.
//
// This app sets <meta name="turbo-refresh-method" content="morph">, so Turbo
// Stream `refresh` broadcasts (e.g. live score updates on a deal) morph the
// page in place via idiomorph instead of replacing it.
//
// Alpine hides x-show/x-cloak elements at runtime: after init it removes the
// `x-cloak` attribute and sets an inline `style="display: none"` on anything
// whose x-show is false. Neither of those exists in the freshly-rendered server
// HTML. When idiomorph reconciles the live node toward that server markup it
// strips the inline `display: none` (and would re-add x-cloak). Alpine's x-show
// effect only re-runs when its state changes, so it never re-hides the element,
// and the dropdown/menu flashes open on every morph.
//
// Guard: when Turbo is about to morph an Alpine-controlled element's `style` or
// `x-cloak`, cancel that single attribute mutation so Alpine's live value wins.
// Everything else about the element still morphs normally.
document.addEventListener("turbo:before-morph-attribute", (event) => {
  const el = event.target
  const attr = event.detail.attributeName

  const alpineControlled =
    el._x_dataStack ||
    el.hasAttribute?.("x-show") ||
    el.hasAttribute?.("x-cloak") ||
    el.hasAttribute?.("x-transition")

  if (alpineControlled && (attr === "style" || attr === "x-cloak")) {
    event.preventDefault()
  }
})
