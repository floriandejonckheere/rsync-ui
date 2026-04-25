import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "path"]

  prefill() {
    const selected = this.selectTarget.selectedOptions[0]
    const path = selected?.dataset?.path

    if (path) this.pathTarget.value = path
  }
}
