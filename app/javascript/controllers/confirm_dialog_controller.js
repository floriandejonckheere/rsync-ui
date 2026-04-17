import { Controller } from "@hotwired/stimulus"
import * as Turbo from "@hotwired/turbo"

export default class extends Controller {
  static targets = ["title", "message", "confirmButton", "cancelButton"]

  connect() {
    this.setupTurboConfirm()
  }

  setupTurboConfirm() {
    Turbo.config.forms.confirm = (message, element) => {
      return new Promise((resolve) => {
        this.resolvePromise = resolve

        // Set the message
        this.messageTarget.textContent = message

        // Set custom title if provided
        const title = element?.dataset?.turboConfirmTitle
        if (title) {
          this.titleTarget.textContent = title
        }

        // Set custom confirm button text if provided
        const confirmText = element?.dataset?.turboConfirmButton
        if (confirmText) {
          this.confirmButtonTarget.textContent = confirmText
        }

        // Set destructive style if specified
        const isDestructive = element?.dataset?.turboConfirmDestructive !== undefined
        if (isDestructive) {
          this.confirmButtonTarget.classList.remove("btn-primary")
          this.confirmButtonTarget.classList.add("btn-destructive")
        } else {
          this.confirmButtonTarget.classList.remove("btn-destructive")
          this.confirmButtonTarget.classList.add("btn-primary")
        }

        // Show the dialog
        this.element.showModal()

        // Handle dialog close
        this.element.addEventListener("close", this.handleClose.bind(this), { once: true })
      })
    }
  }

  handleClose() {
    const returnValue = this.element.returnValue
    this.resolvePromise(returnValue === "confirm")

    // Reset the dialog
    this.element.returnValue = ""
  }

  cancel() {
    this.element.close("cancel")
  }
}
