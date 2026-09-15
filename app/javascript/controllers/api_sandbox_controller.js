import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["path", "output", "details"]
  static values = { prefix: String }

  async run() {
    const path = this.pathTarget.value.trim()
    if (!path) return

    this.detailsTarget.open = true
    this.outputTarget.textContent = "読み込み中…"

    const url = this.prefixValue + path

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const text = await response.text()

      let body = text
      try {
        body = JSON.stringify(JSON.parse(text), null, 2)
      } catch {
        // not JSON (e.g. an HTML error page) — show as-is
      }

      this.outputTarget.textContent = `HTTP ${response.status}\n\n${body}`
    } catch (error) {
      this.outputTarget.textContent = `リクエストに失敗しました: ${error.message}`
    }
  }
}
