import { Controller } from "@hotwired/stimulus"

const ORDER = ["5", "10", "20", "all"]
const KEY_TO_PERIOD = { s: "5", m: "10", l: "20", a: "all" }

export default class extends Controller {
  static targets = ["rate", "button"]
  static values = { period: { type: String, default: "all" } }

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    window.addEventListener("keydown", this.boundKeydown)
    this.render()
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundKeydown)
  }

  handleKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return

    if (KEY_TO_PERIOD[event.key]) {
      this.periodValue = KEY_TO_PERIOD[event.key]
    } else if (event.key === "<") {
      this.step(1)
    } else if (event.key === ">") {
      this.step(-1)
    }
  }

  step(direction) {
    const index = ORDER.indexOf(this.periodValue)
    const nextIndex = Math.min(Math.max(index + direction, 0), ORDER.length - 1)
    this.periodValue = ORDER[nextIndex]
  }

  setPeriod(event) {
    this.periodValue = event.currentTarget.dataset.period
  }

  periodValueChanged() {
    this.render()
  }

  render() {
    const attr = `data-rate-${this.periodValue}`

    this.rateTargets.forEach((el) => {
      el.textContent = el.getAttribute(attr) || "—"
    })

    this.buttonTargets.forEach((el) => {
      el.classList.toggle("active", el.dataset.period === this.periodValue)
    })
  }
}
