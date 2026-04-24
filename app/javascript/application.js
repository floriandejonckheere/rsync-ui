// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import 'basecoat-css/all';
import "./controllers"

// Basecoat only hooks into DOMContentLoaded, which Turbo Drive does not re-fire on
// navigation. Turbo also replaces document.body via replaceWith(), detaching the
// MutationObserver Basecoat started on the old body. Re-init on every subsequent
// turbo:load: stop the stale observer, reinitialize all components, restart the observer.
let initialPageLoad = true

document.addEventListener('turbo:load', () => {
  if (initialPageLoad) {
    initialPageLoad = false
    return
  }

  window.basecoat?.stop()
  window.basecoat?.initAll()
  window.basecoat?.start()
})
