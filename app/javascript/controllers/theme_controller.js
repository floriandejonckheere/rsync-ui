import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  initialize() {
    // Fall back to light mode if no preference is set
    if (localStorage.getItem("dark-mode") === null) {
      localStorage.setItem("dark-mode", "false")
    }

    // Watch for changes to the system preference
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", event => {
      if (event.matches) {
        this.setTheme("dark")
      } else {
        this.setTheme("light")
      }
    });
  }

  toggleTargetConnected(target) {
    if (localStorage.getItem("dark-mode") === "true") {
      this.setTheme("dark")
    } else {
      this.setTheme("light")
    }
  }

  toggle(event) {
    event.preventDefault()

    if (localStorage.getItem("dark-mode") === "true") {
      this.setTheme("light")
    } else {
      this.setTheme("dark")
    }
  }

  setTheme(theme) {
    if (theme === "dark") {
      // Set the toggle to checked
      this.toggleTarget.checked = true

      // Apply the dark theme
      document.documentElement.classList.add("dark")

      // Save the preference to local storage
      localStorage.setItem("dark-mode", "true")
    } else {
      // Set the toggle to unchecked
      this.toggleTarget.checked = false

      // Remove the dark theme
      document.documentElement.classList.remove("dark")

      // Save the preference to local storage
      localStorage.setItem("dark-mode", "false")
    }
  }
}
