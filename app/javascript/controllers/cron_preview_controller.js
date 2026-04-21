import { Controller } from "@hotwired/stimulus"
import cronstrue from "cronstrue"

export default class extends Controller {
  static targets = ["input", "output"]
  static values = { placeholder: String, invalid: String }

  connect() {
    this.update()
  }

  update() {
    const value = this.inputTarget.value.trim()

    if (value === "") {
      this.outputTarget.textContent = this.placeholderValue
      return
    }

    try {
      this.outputTarget.textContent = cronstrue.toString(value, { use24HourTimeFormat: true })
    } catch (_error) {
      this.outputTarget.textContent = this.invalidValue
    }
  }
}
