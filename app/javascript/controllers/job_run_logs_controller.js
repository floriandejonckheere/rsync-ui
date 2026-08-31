import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["log", "status", "loadOlderButton"]
  static values = { jobRunId: String, outputUrl: String }

  async connect() {
    this.subscription = await cable.subscribeTo(
      { channel: "JobRunLogsChannel", job_run_id: this.jobRunIdValue },
      { received: (data) => this.#handleMessage(data) },
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  async loadOlder() {
    if (this.hasLoadOlderButtonTarget) this.loadOlderButtonTarget.disabled = true

    try {
      const response = await fetch(this.outputUrlValue, {
        headers: { Accept: "text/plain" },
      })

      const content = await response.text()
      this.logTarget.textContent = content.replace(/\r/g, "") + this.logTarget.textContent
    } finally {
      if (this.hasLoadOlderButtonTarget) this.loadOlderButtonTarget.remove()
    }
  }

  #handleMessage(data) {
    if (data.type === "log") {
      this.logTarget.textContent += data.content.replace(/\r/g, "")
      this.logTarget.scrollTop = this.logTarget.scrollHeight
    } else if (data.type === "status" && this.hasStatusTarget) {
      this.statusTarget.textContent = data.content
    }
  }
}
