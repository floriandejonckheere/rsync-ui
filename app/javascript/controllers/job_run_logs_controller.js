import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"

const STATUS_CLASSES = {
  pending: "text-gray-700 dark:text-gray-300",
  running: "text-blue-700 dark:text-blue-300",
  completed: "text-green-700 dark:text-green-300",
  failed: "text-red-700 dark:text-red-300",
  canceled: "text-gray-700 dark:text-gray-300",
  errored: "text-red-700 dark:text-red-300",
}

export default class extends Controller {
  static targets = ["log", "status", "jobStatus", "completedAt", "logCard", "completedMessage"]
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
        this.jobStatusTarget.className = STATUS_CLASSES[data.status] ?? "text-gray-700 dark:text-gray-300"
        this.jobStatusTarget.textContent = data.status_text
      }
      if (this.hasCompletedAtTarget) {
        this.completedAtTarget.textContent = data.completed_at_text
      }
      if (this.hasLogCardTarget) {
        this.logCardTarget.classList.add("hidden")
      }
      if (this.hasCompletedMessageTarget) {
        this.completedMessageTarget.classList.remove("hidden")
      }
    }
  }
}
