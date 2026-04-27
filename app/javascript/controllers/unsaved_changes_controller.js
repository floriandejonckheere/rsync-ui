import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.dirty = false
    this.onBeforeUnload = this.onBeforeUnload.bind(this)
    this.onBeforeVisit = this.onBeforeVisit.bind(this)
    this.markDirty = this.markDirty.bind(this)
    this.clearDirty = this.clearDirty.bind(this)

    this.element.addEventListener("change", this.markDirty)
    this.element.addEventListener("input", this.markDirty)
    this.element.addEventListener("submit", this.clearDirty)
    window.addEventListener("beforeunload", this.onBeforeUnload)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
  }

  disconnect() {
    this.element.removeEventListener("change", this.markDirty)
    this.element.removeEventListener("input", this.markDirty)
    this.element.removeEventListener("submit", this.clearDirty)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
  }

  markDirty() {
    this.dirty = true
  }

  clearDirty() {
    this.dirty = false
  }

  onBeforeUnload(event) {
    if (this.dirty) {
      event.preventDefault()
    }
  }

  onBeforeVisit(event) {
    if (this.dirty && !confirm("You have unsaved changes. Leave this page?")) {
      event.preventDefault()
    }
  }
}
