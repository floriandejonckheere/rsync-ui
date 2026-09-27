import { Controller } from "@hotwired/stimulus"

// Applies the job form's option rules (implied and delete options) per job column in the bulk edit grid,
// and only submits the modified jobs
export default class extends Controller {
  static targets = ["option"]
  static values = { implied: Object, delete: Array, deleteTiming: Array }

  connect() {
    this.options = new Map(this.optionTargets.map(option => [this.key(option.dataset.job, option.dataset.option), option]))

    this.jobs().forEach(job => this.sync(job))
  }

  toggle(event) {
    const { job, option } = event.currentTarget.dataset

    // Enabling a more specific delete option enables --delete
    if (event.currentTarget.checked && this.deleteValue.includes(option)) this.option(job, "opt_delete").checked = true

    // Disabling --delete disables the more specific delete options
    if (!event.currentTarget.checked && option === "opt_delete") this.deleteValue.forEach(name => this.option(job, name).checked = false)

    this.sync(job)
  }

  // Toggle the switch when clicking anywhere in its cell
  toggleCell(event) {
    const option = event.currentTarget.querySelector("input[type='checkbox']")

    if (event.target === option || option.disabled) return

    option.click()
  }

  // Leave out the unmodified jobs, so that only the modified ones are updated
  submit() {
    this.jobs()
      .filter(job => !this.dirty(job))
      .forEach(job => {
        this.element
          .querySelectorAll(`input[name^="jobs[${job}]"]`)
          .forEach(input => input.disabled = true)
      })
  }

  sync(job) {
    this.syncTimings(job)
    this.syncImplied(job)
  }

  dirty(job) {
    return this.jobOptions(job).some(option => this.changed(option))
  }

  // Compared to the saved value rather than the rendered one, which differs after a failed submit.
  // Locked implied options are not submitted, so they are never changed.
  changed(option) {
    return option.dataset.impliedPrevious === undefined && option.checked !== (option.dataset.saved === "true")
  }

  jobOptions(job) {
    return this.optionTargets.filter(option => option.dataset.job === job)
  }

  // Only one --delete-WHEN option may be set at a time
  syncTimings(job) {
    const timings = this.deleteTimingValue.map(timing => this.option(job, timing))
    const selected = timings.find(timing => timing.checked)

    timings.forEach(timing => {
      if (selected && timing !== selected) timing.checked = false

      timing.disabled = !!selected && timing !== selected
    })
  }

  // Implied options are checked and locked, and not submitted so their saved value is left untouched
  syncImplied(job) {
    const implied = new Set(
      Object.entries(this.impliedValue)
        .filter(([source]) => this.option(job, source).checked)
        .flatMap(([, options]) => options),
    )

    Object.values(this.impliedValue).flat().forEach(name => {
      const option = this.option(job, name)
      const hidden = this.element.querySelector(`input[type="hidden"][name="${option.name}"]`)

      if (implied.has(name)) {
        if (option.dataset.impliedPrevious === undefined) option.dataset.impliedPrevious = option.checked

        option.checked = true
        option.disabled = true
        hidden.disabled = true
      } else if (option.dataset.impliedPrevious !== undefined) {
        option.checked = option.dataset.impliedPrevious === "true"
        option.disabled = false
        hidden.disabled = false

        delete option.dataset.impliedPrevious
      }
    })
  }

  jobs() {
    return [...new Set(this.optionTargets.map(option => option.dataset.job))]
  }

  option(job, name) {
    return this.options.get(this.key(job, name))
  }

  key(job, name) {
    return `${job}:${name}`
  }
}
