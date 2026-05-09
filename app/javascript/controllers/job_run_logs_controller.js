import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["log", "status", "jobStatus", "completedAt", "logCard", "outputFrame"]
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
      this.logTarget.textContent += data.content
    } else if (data.type === "status" && this.hasStatusTarget) {
      this.statusTarget.textContent = data.content
    } else if (data.type === "progress" && this.hasJobStatusTarget) {
      this.jobStatusTarget.textContent = data.status_text
    } else if (data.type === "complete") {
      if (this.hasJobStatusTarget) {
        this.jobStatusTarget.dataset.jobRunStatus = data.status
        this.jobStatusTarget.textContent = data.status_text
      }
      if (this.hasCompletedAtTarget) {
        this.completedAtTarget.textContent = data.completed_at_text
      }
      if (this.hasLogCardTarget) {
        this.logCardTarget.classList.add("hidden")
      }
      if (this.hasOutputFrameTarget) {
        this.outputFrameTarget.setAttribute("src", window.location.href)
        this.outputFrameTarget.classList.remove("hidden")
      }
    }
  }
}
