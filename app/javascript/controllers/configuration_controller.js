import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "display", "value"]
  static values = { default: String }

  toggle(event) {
    event.preventDefault()

    this.formTarget.classList.toggle("hidden")
    this.displayTargets.forEach(target => {
      target.classList.toggle("hidden")
    })

    if (!this.formTarget.classList.contains("hidden") && this.hasValueTarget) {
      this.valueTarget.focus()
    }
  }

  revert(event) {
    event.preventDefault()

    if (this.hasValueTarget && this.hasDefaultValue) {
      if (this.valueTarget.type === "checkbox") {
        this.valueTarget.checked = this.defaultValue === "true" || this.defaultValue === "1"
      } else {
        this.valueTarget.value = this.defaultValue
      }
    }
  }

  navigateToDependency(event) {
    event.preventDefault()

    const href = event.currentTarget.getAttribute("href")
    const targetId = href.substring(1)
    const targetElement = document.getElementById(targetId)

    if (targetElement) {
      const detailsElement = targetElement.closest("details")
      if (detailsElement) {
        detailsElement.open = true
      }

      targetElement.scrollIntoView({ behavior: "smooth", block: "center" })
      targetElement.classList.add("bg-primary-50", "dark:bg-primary-900/20")
      setTimeout(() => {
        targetElement.classList.remove("bg-primary-50", "dark:bg-primary-900/20")
      }, 2000)
    }
  }
}
