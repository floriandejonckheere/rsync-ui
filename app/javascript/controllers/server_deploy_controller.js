import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "spinner", "host", "port", "username"]
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
    this.hostTarget.value = form.querySelector("[name='server[host]']").value
    this.portTarget.value = form.querySelector("[name='server[port]']").value
    this.usernameTarget.value = form.querySelector("[name='server[username]']").value
  }

  #sourceFormListener = null

  #updateButton(form) {
    const password = form.querySelector("[name='server[password]']")?.value
    const sshKey = form.querySelector("[name='server[ssh_key]']")?.value
    this.buttonTarget.disabled = !!(password || sshKey)
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.iconTarget.classList.toggle("hidden", loading)
    this.spinnerTarget.classList.toggle("hidden", !loading)
  }
}
