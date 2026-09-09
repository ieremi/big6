import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["help", "helpList"]

  handleKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey || this.isTyping(event.target)) return

    if (event.key === "?") {
      event.preventDefault()
      this.toggleHelp()
      return
    }

    if (event.key === "Escape") {
      this.closeHelp()
      return
    }

    if (!this.helpTarget.hidden) return

    const el = document.querySelector(`[data-shortcut="${window.CSS.escape(event.key)}"]`)
    if (el) {
      event.preventDefault()
      el.click()
    }
  }

  backdropClick(event) {
    if (event.target === this.helpTarget) this.closeHelp()
  }

  toggleHelp() {
    if (this.helpTarget.hidden) {
      this.openHelp()
    } else {
      this.closeHelp()
    }
  }

  openHelp() {
    this.renderHelpList()
    this.helpTarget.hidden = false
  }

  closeHelp() {
    this.helpTarget.hidden = true
  }

  renderHelpList() {
    const items = Array.from(document.querySelectorAll("[data-shortcut]"))

    this.helpListTarget.innerHTML = items
      .map((el) => {
        const key = el.dataset.shortcut
        const label = el.dataset.shortcutLabel || el.textContent.trim()
        const li = document.createElement("li")
        const kbd = document.createElement("kbd")
        kbd.textContent = key
        li.append(kbd, " " + label)
        return li.outerHTML
      })
      .join("")
  }

  isTyping(target) {
    const tag = target.tagName
    return tag === "INPUT" || tag === "SELECT" || tag === "TEXTAREA" || target.isContentEditable
  }
}
