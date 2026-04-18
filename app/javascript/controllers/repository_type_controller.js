import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "input"]

  connect() {
    this.activate(this.inputTarget.value || "local")
  }

  select(event) {
    this.activate(event.currentTarget.dataset.value)
  }

  activate(value) {
    this.inputTarget.value = value

    this.tabTargets.forEach(tab => {
      tab.setAttribute("aria-selected", tab.dataset.value === value ? "true" : "false")
    })

    this.panelTargets.forEach(panel => {
      if (panel.dataset.value === value) {
        panel.removeAttribute("hidden")
      } else {
        panel.setAttribute("hidden", "")
      }
    })
  }
}
