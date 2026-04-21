import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "input", "form"]
  static values = {
    expanded: { type: Boolean, default: false },
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.debounceTimeout = null

    // Check if there's an initial query and expand if so
    if (this.hasInputTarget && this.inputTarget.value.trim() !== "") {
      this.expandedValue = true
      this.updateState()
    }
  }

  toggle(event) {
    event.preventDefault()
    this.expandedValue = !this.expandedValue
    this.updateState()

    if (this.expandedValue && this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }

  close(event) {
    event.preventDefault()
    this.inputTarget.value = ""
    this.expandedValue = false
    this.updateState()
    this.submitSearch()
  }

  handleInput() {
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout)
    }

    this.debounceTimeout = setTimeout(() => {
      this.isSubmitting = true
      this.submitSearch()
    }, this.debounceValue)
  }

  submitSearch() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  restoreFocus(event) {
    if (this.isSubmitting && this.hasInputTarget) {
      this.isSubmitting = false
      const length = this.inputTarget.value.length
      this.inputTarget.focus()
      this.inputTarget.setSelectionRange(length, length)
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close(event)
    }
  }

  updateState() {
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.toggle("hidden", this.expandedValue)
    }

    if (this.hasFormTarget) {
      this.formTarget.classList.toggle("hidden", !this.expandedValue)
    }
  }
}
