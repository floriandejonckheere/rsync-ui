import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "path", "pathHint", "input"]

  connect() {
    this.updatePathHint()
  }

  prefill(event) {
    const path = this.selectedPath(event)

    if (path) this.pathTarget.value = path
    this.updatePathHint()
  }

  updatePathHint() {
    if (!this.hasPathHintTarget) return

    const path = this.pathTarget.value.trim()
    const showHint = path.length > 0 && !path.endsWith("/")

    this.pathHintTarget.hidden = !showHint
  }

  selectedPath(event) {
    if (event?.detail?.value !== undefined) {
      const option = this.selectTarget.querySelector(`[role="option"][data-value="${CSS.escape(event.detail.value)}"]`)
      return option?.dataset?.path
    }

    const selected = this.hasInputTarget ? this.selectTarget.querySelector(`[role="option"][data-value="${CSS.escape(this.inputTarget.value)}"]`) : this.selectTarget.selectedOptions?.[0]
    return selected?.dataset?.path
  }
}
