import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]
  static values = { fieldName: String, placeholder: String }

  add() {
    const clone = this.templateTarget.content.cloneNode(true)
    const input = clone.querySelector("input[type=text]")
    input.name = this.fieldNameValue
    input.placeholder = this.placeholderValue
    this.listTarget.appendChild(clone)
  }

  remove(event) {
    event.currentTarget.closest("[data-pattern-row]").remove()
  }
}
