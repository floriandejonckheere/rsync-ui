import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["jobStatus", "startedAt", "completedAt", "duration", "progressBar", "progressFill", "logCard", "outputFrame"]
  static values = { jobRunId: String }

  async connect() {
    this.subscription = await cable.subscribeTo(
      { channel: "JobRunStatusChannel", job_run_id: this.jobRunIdValue },
      { received: (data) => this.#handleMessage(data) },
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  #relativeTime(isoString) {
    if (!isoString) return "—"
    const date = new Date(isoString)
    const diffMs = Date.now() - date
    const rtf = new Intl.RelativeTimeFormat(undefined, { numeric: "auto" })
    const diffSecs = Math.round(diffMs / 1000)
    const diffMins = Math.round(diffSecs / 60)
    const diffHours = Math.round(diffMins / 60)
    const diffDays = Math.round(diffHours / 24)
    if (diffSecs < 60) return rtf.format(-diffSecs, "second")
    if (diffMins < 60) return rtf.format(-diffMins, "minute")
    if (diffHours < 24) return rtf.format(-diffHours, "hour")
    return rtf.format(-diffDays, "day")
  }

  #handleMessage(data) {
    if (data.type === "started") {
      if (this.hasJobStatusTarget) {
        this.jobStatusTarget.dataset.jobRunStatus = data.status
        this.jobStatusTarget.textContent = data.status_text
      }
      if (this.hasStartedAtTarget) {
        this.startedAtTarget.textContent = this.#relativeTime(data.started_at)
      }
    } else if (data.type === "progress") {
      if (this.hasJobStatusTarget) {
        this.jobStatusTarget.textContent = data.status_text
      }
      if (this.hasProgressBarTarget) {
        this.progressBarTarget.classList.remove("hidden")
        this.progressBarTarget.ariaValueNow = data.progress
      }
      if (this.hasProgressFillTarget) {
        this.progressFillTarget.style.transform = `translateX(-${100 - data.progress}%)`
      }
    } else if (data.type === "complete") {
      if (this.hasJobStatusTarget) {
        this.jobStatusTarget.dataset.jobRunStatus = data.status
        this.jobStatusTarget.textContent = data.status_text
      }
      if (this.hasStartedAtTarget && data.started_at) {
        this.startedAtTarget.textContent = this.#relativeTime(data.started_at)
      }
      if (this.hasCompletedAtTarget) {
        this.completedAtTarget.textContent = this.#relativeTime(data.completed_at)
      }
      if (this.hasDurationTarget && data.duration) {
        this.durationTarget.textContent = data.duration
      }
      if (this.hasProgressBarTarget) {
        this.progressBarTarget.classList.add("hidden")
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
