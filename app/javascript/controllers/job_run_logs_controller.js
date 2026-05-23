import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["log", "status"]
  static values = { jobRunId: String }

  async connect() {
    this.subscription = await cable.subscribeTo(
      { channel: "JobRunLogsChannel", job_run_id: this.jobRunIdValue },
      { received: (data) => this.#handleMessage(data) },
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
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
