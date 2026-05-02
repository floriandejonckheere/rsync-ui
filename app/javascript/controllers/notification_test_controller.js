import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "spinner", "url", "notificationId"]
  static values = { sourceForm: String }

  connect() {
    this.element.addEventListener("turbo:submit-start", () => this.#setLoading(true))
    this.element.addEventListener("turbo:submit-end", () => this.#setLoading(false))

    const form = document.getElementById(this.sourceFormValue)
    if (form) {
      this.#sourceFormListener = () => this.#updateButton(form)
      form.addEventListener("input", this.#sourceFormListener)
      this.#updateButton(form)
    }
  }

  disconnect() {
    const form = document.getElementById(this.sourceFormValue)
    if (form && this.#sourceFormListener) {
      form.removeEventListener("input", this.#sourceFormListener)
    }
  }

  sync() {
    const form = document.getElementById(this.sourceFormValue)
    this.urlTarget.value = form.querySelector("[name='notification[url]']").value
  }

  #sourceFormListener = null

  #updateButton(form) {
    const url = form.querySelector("[name='notification[url]']")?.value.trim()
    this.buttonTarget.disabled = !url
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.iconTarget.classList.toggle("hidden", loading)
    this.spinnerTarget.classList.toggle("hidden", !loading)
  }
}
