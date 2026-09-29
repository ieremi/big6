import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cell", "button", "resultsColumn", "attendanceColumn", "attendanceFigure", "weekendButton"]
  static values = {
    mode: { type: String, default: "results" },
    // The attendance totals and averages of the games on a Saturday or a Sunday only (平日の試合をのぞく).
    weekendsOnly: { type: Boolean, default: false }
  }

  connect() {
    this.render()
  }

  setMode(event) {
    this.modeValue = event.currentTarget.dataset.mode
  }

  // Leaving weekday games out is about attendance, so from the results it
  // switches to the attendance with them left out.
  toggleWeekends() {
    this.weekendsOnlyValue = this.modeValue === "attendance" ? !this.weekendsOnlyValue : true
    this.modeValue = "attendance"
  }

  modeValueChanged() {
    this.render()
  }

  weekendsOnlyValueChanged() {
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

    // Each carries both figures, as data-all and data-weekend.
    this.attendanceFigureTargets.forEach((el) => {
      el.textContent = this.weekendsOnlyValue ? el.dataset.weekend : el.dataset.all
    })

    this.weekendButtonTargets.forEach((el) => {
      const on = this.weekendsOnlyValue && attendance
      el.classList.toggle("active", on)
      el.setAttribute("aria-pressed", on ? "true" : "false")
    })
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
