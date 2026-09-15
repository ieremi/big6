import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop", "button"]

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    window.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  toggle() {
    if (this.drawerTarget.classList.contains("is-open")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.drawerTarget.classList.add("is-open")
    this.backdropTarget.classList.add("is-open")
    document.body.classList.add("nav-open")
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.drawerTarget.classList.remove("is-open")
    this.backdropTarget.classList.remove("is-open")
    document.body.classList.remove("nav-open")
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
