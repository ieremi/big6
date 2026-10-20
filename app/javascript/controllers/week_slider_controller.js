import { Controller } from "@hotwired/stimulus"

// The week slider over 優勝のゆくえ on the standings page: while it is dragged
// the label follows ("第5週終了時点（10月12日まで）"), and once it is let go the
// form loads that week's race into the "title-race" turbo frame. The slider is
// set again from the week of the race in the frame (data-week) whenever the
// frame loads or the page comes back from history, so the two always agree.
export default class extends Controller {
  static targets = ["input", "label"]
  static values = { labels: Object }

  connect() {
    this.boundSync = this.sync.bind(this)
    document.addEventListener("turbo:frame-load", this.boundSync)
    this.sync()
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundSync)
  }

  show() {
    const label = this.labelsValue[this.inputTarget.value] || ""
    this.labelTarget.textContent = label
    this.inputTarget.setAttribute("aria-valuetext", label)
  }

  submit() {
    this.element.requestSubmit()
  }

  sync() {
    const shown = document.querySelector("#title-race [data-week]")
    if (!shown) return

    this.inputTarget.value = shown.dataset.week
    this.show()
  }
}
