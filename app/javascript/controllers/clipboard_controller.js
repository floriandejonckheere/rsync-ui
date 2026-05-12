import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "copyIcon", "checkIcon"]

  copy() {
    const text = this.sourceTarget.textContent.replace(/\s*\\\s*\n\s*/g, " ").trim()

    navigator.clipboard.writeText(text).then(() => this._showSuccess())
  }

  _showSuccess() {
    this.copyIconTarget.classList.add("hidden")
    this.checkIconTarget.classList.remove("hidden")

    setTimeout(() => {
      this.checkIconTarget.classList.add("hidden")
      this.copyIconTarget.classList.remove("hidden")
    }, 2000)
  }
}
