import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "spinner", "host", "port", "username", "password", "sshKey", "serverId"]
  static values = { sourceForm: String }

  connect() {
    this.element.addEventListener("turbo:submit-start", () => this.#setLoading(true))
    this.element.addEventListener("turbo:submit-end", () => this.#setLoading(false))
  }

  sync() {
    const form = document.getElementById(this.sourceFormValue)
    this.hostTarget.value = form.querySelector("[name='server[host]']").value
    this.portTarget.value = form.querySelector("[name='server[port]']").value
    this.usernameTarget.value = form.querySelector("[name='server[username]']").value
    this.passwordTarget.value = form.querySelector("[name='server[password]']").value
    this.sshKeyTarget.value = form.querySelector("[name='server[ssh_key]']").value
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.iconTarget.classList.toggle("hidden", loading)
    this.spinnerTarget.classList.toggle("hidden", !loading)
  }
}
