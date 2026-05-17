import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sshField", "hint"]
  static values = { remoteIds: Array }

  connect() {
    this.update()
  }

  update() {
    const sourceId = this.element.querySelector('[name="job[source_repository_id]"]')?.value ?? ""
    const destinationId = this.element.querySelector('[name="job[destination_repository_id]"]')?.value ?? ""
    const hasRemote = this.remoteIdsValue.includes(sourceId) || this.remoteIdsValue.includes(destinationId)

    this.sshFieldTarget.disabled = !hasRemote
    this.hintTarget.hidden = hasRemote
  }
}
