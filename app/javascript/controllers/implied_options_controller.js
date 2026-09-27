import { Controller } from "@hotwired/stimulus"

// Checks and locks options that are implied by another checked option
// (e.g. --archive implies --recursive), restoring them when it is unchecked
export default class extends Controller {
  static targets = ["source"]

  connect() {
    this.sync()
  }

  sync() {
    const implied = new Set(
      this.sourceTargets
        .filter(source => source.checked)
        .flatMap(source => source.dataset.implies.split(" ")),
    )

    const names = new Set(this.sourceTargets.flatMap(source => source.dataset.implies.split(" ")))

    names.forEach(name => {
      const option = this.element.querySelector(`input[type="checkbox"][name$="[${name}]"]`)

      if (!option) return

      if (implied.has(name)) {
        if (option.dataset.impliedPrevious === undefined) option.dataset.impliedPrevious = option.checked

        option.checked = true
        option.disabled = true
      } else if (option.dataset.impliedPrevious !== undefined) {
        option.checked = option.dataset.impliedPrevious === "true"
        option.disabled = false

        delete option.dataset.impliedPrevious
      }
    })
  }
}
