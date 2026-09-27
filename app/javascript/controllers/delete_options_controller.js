import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["delete", "timing", "excluded"]

  connect() {
    this.syncTimings()
  }

  // Disabling --delete disables the more specific delete options
  toggleDelete() {
    if (this.deleteTarget.checked) return

    [...this.timingTargets, ...this.excludedTargets].forEach(option => option.checked = false)

    this.syncTimings()
  }

  enableDelete(event) {
    if (event.currentTarget.checked) this.deleteTarget.checked = true
  }

  selectTiming(event) {
    this.enableDelete(event)
    this.syncTimings()
  }

  // Only one --delete-WHEN option may be set at a time
  syncTimings() {
    const selected = this.timingTargets.find(timing => timing.checked)

    this.timingTargets.forEach(timing => {
      if (selected && timing !== selected) timing.checked = false

      timing.disabled = !!selected && timing !== selected
    })
  }
}
