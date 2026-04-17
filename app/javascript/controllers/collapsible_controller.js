import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.updateState()
    this.checkHash()
    this.hashChangeHandler = this.checkHash.bind(this)
    window.addEventListener("hashchange", this.hashChangeHandler)
  }

  disconnect() {
    window.removeEventListener("hashchange", this.hashChangeHandler)
  }

  toggle(event) {
    event.preventDefault()
    this.openValue = !this.openValue
    this.updateState()
  }

  open() {
    this.openValue = true
    this.updateState()
  }

  checkHash() {
    const hash = window.location.hash.slice(1)
    if (hash && this.element.id === hash) {
      this.open()
    }
  }

  updateState() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden", !this.openValue)
    }

    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180", this.openValue)
    }
  }
}
