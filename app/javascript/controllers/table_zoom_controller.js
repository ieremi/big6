import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "backdrop", "panel"]

  toggle() {
    const zoomed = this.element.classList.toggle("is-zoomed")
    document.body.classList.toggle("table-zoom-open", zoomed)
    this.backdropTarget.classList.toggle("is-open", zoomed)
    this.buttonTarget.textContent = zoomed ? "✕ 閉じる" : "⤢ 拡大表示"
  }

  close() {
    if (!this.element.classList.contains("is-zoomed")) return

    this.toggle()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
