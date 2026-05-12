import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "path", "pathHint"]

  connect() {
    this.updatePathHint()
  }

  prefill() {
    const selected = this.selectTarget.selectedOptions[0]
    const path = selected?.dataset?.path

    if (path) this.pathTarget.value = path
    this.updatePathHint()
  }

  updatePathHint() {
    if (!this.hasPathHintTarget) return

    const path = this.pathTarget.value.trim()
    const showHint = path.length > 0 && !path.endsWith("/")

    this.pathHintTarget.hidden = !showHint
  }
}
