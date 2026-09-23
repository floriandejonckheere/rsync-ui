import { Controller } from "@hotwired/stimulus"

// Toggles a category heading into an inline form, submitted on enter
export default class extends Controller {
  static targets = ["display", "form", "input"]

  edit() {
    this.toggle(true)

    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel() {
    this.formTarget.reset()

    this.toggle(false)
  }

  toggle(editing) {
    this.displayTarget.classList.toggle("hidden", editing)
    this.formTarget.classList.toggle("hidden", !editing)
  }
}
