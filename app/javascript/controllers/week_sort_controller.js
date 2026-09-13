import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "view"]
  static values = { mode: { type: String, default: "card" } }

  setMode(event) {
    this.modeValue = event.currentTarget.dataset.mode
  }

  modeValueChanged() {
    this.viewTargets.forEach((el) => {
      el.hidden = el.dataset.mode !== this.modeValue
    })

    this.buttonTargets.forEach((el) => {
      el.classList.toggle("active", el.dataset.mode === this.modeValue)
    })
  }
}
