import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cell", "button"]
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

    this.cellTargets.forEach((el) => {
      el.textContent = el.getAttribute(attr) || "-"
    })

    this.buttonTargets.forEach((el) => {
      el.classList.toggle("active", el.dataset.mode === this.modeValue)
    })
  }
}
