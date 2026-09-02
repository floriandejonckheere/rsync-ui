import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["jobStatus", "startedAt", "completedAt", "duration", "bytesCopied", "bytesCopiedValue", "exitStatus", "exitStatusValue", "progressBar", "progressFill", "speedInfo", "logCard", "outputFrame"]
  static values = { jobRunId: String }

  async connect() {
    this.subscription = await cable.subscribeTo(
      { channel: "JobRunStatusChannel", job_run_id: this.jobRunIdValue },
      { received: (data) => this.#handleMessage(data) },
    )

    this.#startDurationTimer()
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.#stopDurationTimer()
  }

  #startDurationTimer() {
    if (!this.hasDurationTarget || this.durationInterval) return
    if (!this.durationTarget.dataset.startedAt) return

    this.#tickDuration()
    this.durationInterval = setInterval(() => this.#tickDuration(), 1000)
  }

  #stopDurationTimer() {
    if (this.durationInterval) {
      clearInterval(this.durationInterval)
      this.durationInterval = null
    }
  }

  #tickDuration() {
    const startedAt = this.durationTarget.dataset.startedAt
    if (!startedAt) return

    const seconds = Math.max(0, Math.floor((Date.now() - new Date(startedAt)) / 1000))
    this.durationTarget.textContent = this.#formatRemainingTime(seconds)
  }

  #formatBytes(bytes) {
    const units = ["Bytes", "KB", "MB", "GB", "TB", "PB"]
    if (bytes < 1024) return `${bytes} Bytes`
    const exponent = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
    return `${(bytes / 1024 ** exponent).toFixed(1)} ${units[exponent]}`
  }

  #formatSpeed(bytesPerSec) {
    if (bytesPerSec >= 1e9) return `${(bytesPerSec / 1e9).toFixed(0)} GB/s`
    if (bytesPerSec >= 1e6) return `${(bytesPerSec / 1e6).toFixed(0)} MB/s`
    if (bytesPerSec >= 1e3) return `${(bytesPerSec / 1e3).toFixed(0)} kB/s`
    return `${bytesPerSec} B/s`
  }

  #formatRemainingTime(seconds) {
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    const s = seconds % 60
    const pad = (n) => String(n).padStart(2, "0")
    return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`
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
      if (this.hasDurationTarget) {
        this.durationTarget.dataset.startedAt = data.started_at
        this.#startDurationTimer()
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
      if (this.hasSpeedInfoTarget) {
        if (data.speed != null && data.remaining_time != null) {
          const remaining = `${data.remaining_time_approximate ? "~" : ""}${this.#formatRemainingTime(data.remaining_time)}`
          this.speedInfoTarget.textContent = `${this.#formatSpeed(data.speed)} · ${remaining} remaining`
          this.speedInfoTarget.classList.remove("hidden")
        } else if (data.speed != null) {
          this.speedInfoTarget.textContent = this.#formatSpeed(data.speed)
          this.speedInfoTarget.classList.remove("hidden")
        } else {
          this.speedInfoTarget.classList.add("hidden")
        }
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
      this.#stopDurationTimer()
      if (this.hasDurationTarget && data.started_at && data.completed_at) {
        const seconds = Math.max(0, Math.floor((new Date(data.completed_at) - new Date(data.started_at)) / 1000))
        this.durationTarget.textContent = this.#formatRemainingTime(seconds)
      }
      if (this.hasBytesCopiedTarget && this.hasBytesCopiedValueTarget && data.bytes_copied) {
        this.bytesCopiedValueTarget.textContent = this.#formatBytes(data.bytes_copied)
        this.bytesCopiedTarget.classList.remove("hidden")
      }
      if (this.hasExitStatusTarget && this.hasExitStatusValueTarget && data.exit_status) {
        this.exitStatusValueTarget.textContent = data.exit_status
        this.exitStatusTarget.classList.remove("hidden")
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
