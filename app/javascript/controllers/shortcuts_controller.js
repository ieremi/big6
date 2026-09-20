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

    const matches = Array.from(document.querySelectorAll(`[data-shortcut="${window.CSS.escape(event.key)}"]`))
    if (matches.length === 0) return

    event.preventDefault()
    // A key normally does one thing: the first element that has it. The headings
    // of sortable tables mark themselves data-shortcut-all, so that one key sorts
    // the same column of every table on the page.
    const targets = matches[0].hasAttribute("data-shortcut-all") ? matches : [ matches[0] ]
    targets.forEach((el) => el.click())
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
    const seen = new Set()

    this.helpListTarget.innerHTML = items
      .map((el) => {
        const key = el.dataset.shortcut
        const label = el.dataset.shortcutLabel || el.textContent.trim()
        // The same key and label on several tables is one line of help.
        if (seen.has(`${key}\t${label}`)) return ""
        seen.add(`${key}\t${label}`)
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
