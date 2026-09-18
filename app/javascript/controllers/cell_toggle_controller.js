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
    const attendance = this.modeValue === "attendance"

    this.element.classList.toggle("cell-toggle-attendance", attendance)

    this.cellTargets.forEach((el) => {
      const text = el.getAttribute(attr) || "-"

      // Attendance text ("16,000/13,000/2,000") is long enough to need an
      // actual line break after each "/" — relying on CSS white-space to
      // wrap there didn't hold up, so insert real <br> elements instead.
      if (attendance) {
        el.innerHTML = text.split("/").map((part) => this.escapeHtml(part)).join("/<br>")
      } else {
        el.textContent = text
      }
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

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
