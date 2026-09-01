import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"

const SCROLL_THRESHOLD = 20

export default class extends Controller {
  static targets = ["log", "status", "loadOlderButton"]
  static values = { jobRunId: String, outputUrl: String }

  async connect() {
    this.olderContent = ""
    this.lines = []
    this.current = ""

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
      this.olderContent = content.replace(/\r/g, "")
      this.#render()
    } finally {
      if (this.hasLoadOlderButtonTarget) this.loadOlderButtonTarget.remove()
    }
  }

  #handleMessage(data) {
    if (data.type === "log") {
      this.#appendLog(data.content)
    } else if (data.type === "status" && this.hasStatusTarget) {
      this.statusTarget.textContent = data.content
    }
  }

  // rsync progress output uses "\r" to redraw the current line in place rather
  // than starting a new one, so a naive append would print every intermediate
  // progress update on its own line instead of overwriting the previous one.
  #appendLog(content) {
    const parts = content.split(/(\r\n|\r|\n)/)

    for (const part of parts) {
      if (part === "") continue

      if (part === "\r\n" || part === "\n") {
        this.lines.push(this.current)
        this.current = ""
      } else if (part === "\r") {
        this.current = ""
      } else {
        this.current += part
      }
    }

    this.#render()
  }

  #render() {
    const nearBottom =
      this.logTarget.scrollHeight - this.logTarget.scrollTop - this.logTarget.clientHeight <= SCROLL_THRESHOLD

    this.logTarget.textContent = this.olderContent + [...this.lines, this.current].join("\n")

    if (nearBottom) this.logTarget.scrollTop = this.logTarget.scrollHeight
  }
}
