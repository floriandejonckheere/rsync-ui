import { Controller } from "@hotwired/stimulus"
import { StreamActions, visit } from "@hotwired/turbo"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this._debounceTimer = null
    this.element.addEventListener("input", this._onInput)
    this.element.addEventListener("change", this._onChange)
  }

  disconnect() {
    clearTimeout(this._debounceTimer)
    this.element.removeEventListener("input", this._onInput)
    this.element.removeEventListener("change", this._onChange)
  }

  _onInput = () => {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this._fetchPreview(), 300)
  }

  _onChange = () => {
    clearTimeout(this._debounceTimer)
    this._fetchPreview()
  }

  async _fetchPreview() {
    const formData = new FormData(this.element)
    formData.delete("_method")

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: { Accept: "text/html", "X-CSRF-Token": this._csrfToken() },
      body: formData,
    })

    if (!response.ok) return

    const html = await response.text()
    const parser = new DOMParser()
    const doc = parser.parseFromString(html, "text/html")
    const frame = doc.querySelector("turbo-frame#command-preview")

    if (frame) {
      document.querySelector("turbo-frame#command-preview")?.replaceWith(frame)
    }
  }

  _csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content ?? ""
  }
}
