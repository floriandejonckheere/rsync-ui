import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "spinner", "host", "port", "username", "password", "sshKey", "serverId"]
  static values = { sourceForm: String, hasCredentials: Boolean }

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
    this.passwordTarget.value = form.querySelector("[name='server[password]']").value
    this.sshKeyTarget.value = form.querySelector("[name='server[ssh_key]']").value
  }

  #sourceFormListener = null

  #updateButton(form) {
    const host = form.querySelector("[name='server[host]']")?.value.trim()
    const port = form.querySelector("[name='server[port]']")?.value.trim()
    const username = form.querySelector("[name='server[username]']")?.value.trim()
    const password = form.querySelector("[name='server[password]']")?.value.trim()
    const sshKey = form.querySelector("[name='server[ssh_key]']")?.value.trim()

    const hasAuth = !!(password || sshKey || this.hasCredentialsValue)
    this.buttonTarget.disabled = !(host && port && username && hasAuth)
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.iconTarget.classList.toggle("hidden", loading)
    this.spinnerTarget.classList.toggle("hidden", !loading)
  }
}
