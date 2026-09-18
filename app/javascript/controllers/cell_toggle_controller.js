import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cell", "button", "resultsColumn", "attendanceColumn"]
  static values = { mode: { type: String, default: "results" } }

  connect() {
    this.render()
  }

  setMode(event) {
    this.modeValue = event.currentTarget.dataset.mode
  }

  modeValueChanged() {
    this.render()
  }

  render() {
    const attr = `data-${this.modeValue}`

    this.element.classList.toggle("cell-toggle-attendance", this.modeValue === "attendance")

    this.cellTargets.forEach((el) => {
      el.textContent = el.getAttribute(attr) || "-"
    })

    this.buttonTargets.forEach((el) => {
      el.classList.toggle("active", el.dataset.mode === this.modeValue)
    })

    this.resultsColumnTargets.forEach((el) => {
      el.hidden = this.modeValue !== "results"
    })

    this.attendanceColumnTargets.forEach((el) => {
      el.hidden = this.modeValue !== "attendance"
    })
  }
}
