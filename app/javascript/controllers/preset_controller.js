import { Controller } from "@hotwired/stimulus"
import * as Turbo from "@hotwired/turbo"

// Applies a preset of rsync options to the job form, after confirming that
// the current options will be overwritten (or extended, for additive presets)
export default class extends Controller {
  static targets = ["select", "description"]
  static values = { presets: Object }

  connect() {
    this.previous = this.selectTarget.value
    this.describe()
  }

  async select() {
    const key = this.selectTarget.value
    const message = this.selectTarget.selectedOptions[0]?.dataset.confirm

    if (key && !(await Turbo.config.forms.confirm(message, this.selectTarget))) {
      this.selectTarget.value = this.previous
    } else {
      this.previous = key

      if (key) this.apply(this.presetsValue[key])
    }

    this.describe()
  }

  describe() {
    const description = this.selectTarget.selectedOptions[0]?.dataset.description

    this.descriptionTarget.textContent = description ?? ""
    this.descriptionTarget.hidden = !description
  }

  apply(attributes) {
    const form = this.element.closest("form")
    const checkboxes = []

    Object.entries(attributes).forEach(([name, value]) => {
      const checkbox = form.querySelector(`input[type="checkbox"][name$="[${name}]"]`)

      if (checkbox) {
        // Reset any state left behind by the implied and delete options controllers
        delete checkbox.dataset.impliedPrevious
        checkbox.disabled = false
        checkbox.checked = value

        checkboxes.push(checkbox)
      } else {
        const field = form.querySelector(`textarea[name$="[${name}]"], input[type="text"][name$="[${name}]"]`)

        if (field) field.value = value ?? ""
      }
    })

    // Let the other controllers (implied options, delete options, command preview, unsaved changes) catch up
    checkboxes.forEach(checkbox => checkbox.dispatchEvent(new Event("input", { bubbles: true })))
    form.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
