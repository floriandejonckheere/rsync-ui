import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["delete"]

  enableDelete(event) {
    if (event.currentTarget.checked) this.deleteTarget.checked = true
  }
}
