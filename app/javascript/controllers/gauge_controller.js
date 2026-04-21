import { Controller } from "@hotwired/stimulus"
import { Chart, ArcElement, DoughnutController, Tooltip } from "chart.js"

Chart.register(ArcElement, DoughnutController, Tooltip)

const HEALTH_COLORS = {
  ok:       "#22c55e",
  warning:  "#facc15",
  critical: "#ef4444",
}

const TRACK_COLOR_LIGHT = "#f3f4f6" // gray-100
const TRACK_COLOR_DARK  = "#374151" // gray-700

export default class extends Controller {
  static targets = ["canvas"]
  static values  = { percent: Number, health: String }

  connect() {
    const percent   = Math.max(0, Math.min(100, this.percentValue || 0))
    const fillColor = HEALTH_COLORS[this.healthValue] ?? "#9ca3af"
    const trackColor = this.#isDark() ? TRACK_COLOR_DARK : TRACK_COLOR_LIGHT

    this.chart = new Chart(this.canvasTarget, {
      type: "doughnut",
      data: {
        datasets: [{
          data: [percent, 100 - percent],
          backgroundColor: [fillColor, trackColor],
          borderWidth: 0,
        }],
      },
      options: {
        rotation: 225,
        circumference: 270,
        cutout: "75%",
        animation: { animateRotate: true, duration: 600 },
        plugins: {
          legend:  { display: false },
          tooltip: { enabled: false },
        },
        responsive: true,
        maintainAspectRatio: true,
      },
    })
  }

  disconnect() {
    this.chart?.destroy()
  }

  #isDark() {
    return document.documentElement.classList.contains("dark")
  }
}
