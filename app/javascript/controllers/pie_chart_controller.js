import { Controller } from "@hotwired/stimulus"
import { Chart, ArcElement, DoughnutController, Tooltip } from "chart.js"

Chart.register(ArcElement, DoughnutController, Tooltip)

const COLORS = {
  light: {
    completed: "#22c55e",
    failed:    "#ef4444",
    errored:   "#b91c1c",
    canceled:  "#9ca3af",
    pending:   "#3b82f6",
    running:   "#93c5fd",
    remote:    "#f97316",
    local:     "#3b82f6",
  },
  dark: {
    completed: "#4ade80",
    failed:    "#f87171",
    errored:   "#ef4444",
    canceled:  "#6b7280",
    pending:   "#60a5fa",
    running:   "#bfdbfe",
    local:     "#60a5fa",
    remote:    "#fb923c",
  },
}

const FALLBACK = { light: "#e5e7eb", dark: "#374151" }

export default class extends Controller {
  static targets = ["canvas"]
  static values  = { slices: Object, labels: Array }

  connect() {
    const isDark   = document.documentElement.classList.contains("dark")
    const palette  = isDark ? COLORS.dark : COLORS.light
    const fallback = isDark ? FALLBACK.dark : FALLBACK.light

    const slices = this.slicesValue
    const labels = this.labelsValue
    const total  = Object.values(slices).reduce((sum, n) => sum + n, 0)

    const data = total === 0
      ? {
          datasets: [{
            data: [1],
            backgroundColor: [fallback],
            borderWidth: 0,
          }],
        }
      : {
          labels,
          datasets: [{
            data:            Object.values(slices),
            backgroundColor: Object.keys(slices).map(k => palette[k] ?? fallback),
            borderWidth: 0,
          }],
        }

    this.chart = new Chart(this.canvasTarget, {
      type: "doughnut",
      data,
      options: {
        animation: { animateRotate: true, duration: 600 },
        plugins: {
          legend:  { display: false },
          tooltip: {
            enabled: total > 0,
            callbacks: {
              label: (ctx) => ` ${ctx.label}: ${ctx.parsed}`,
            },
          },
        },
        responsive:          true,
        maintainAspectRatio: true,
      },
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
