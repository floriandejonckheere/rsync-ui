import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "spinner"]
  static values = { url: String, sourceForm: String }

  async request() {
    const form = document.getElementById(this.sourceFormValue)

    const data = new FormData()
    data.append("host", form.querySelector("[name='server[host]']").value)
    data.append("port", form.querySelector("[name='server[port]']").value)
    data.append("username", form.querySelector("[name='server[username]']").value)
    data.append("password", form.querySelector("[name='server[password]']").value)
    data.append("ssh_key", form.querySelector("[name='server[ssh_key]']").value)

    this.#setLoading(true)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        },
        body: data,
      })

      const html = await response.text()
      Turbo.renderStreamMessage(html)
    } finally {
      this.#setLoading(false)
    }
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.iconTarget.classList.toggle("hidden", loading)
    this.spinnerTarget.classList.toggle("hidden", !loading)
  }
}
