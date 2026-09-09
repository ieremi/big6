import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["decade"]

  openAll() {
    this.decadeTargets.forEach((el) => { el.open = true })
  }

  closeAll() {
    this.decadeTargets.forEach((el) => { el.open = false })
  }
}
