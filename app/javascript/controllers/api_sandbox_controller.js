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
      const header = `HTTP ${response.status}\n\n`

      let parsed
      try {
        parsed = JSON.parse(text)
      } catch {
        // not JSON (e.g. an HTML error page) — show as-is, unhighlighted
      }

      if (parsed !== undefined) {
        this.outputTarget.innerHTML = this.escape(header) + this.highlightJson(JSON.stringify(parsed, null, 2))
      } else {
        this.outputTarget.textContent = header + text
      }
    } catch (error) {
      this.outputTarget.textContent = `リクエストに失敗しました: ${error.message}`
    }
  }

  highlightJson(json) {
    const escaped = this.escape(json)
    return escaped.replace(
      /("(?:\\u[a-fA-F0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(?:true|false|null)\b|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/g,
      (match) => {
        let cls = "json-number"
        if (match.startsWith("\"")) {
          cls = match.endsWith(":") ? "json-key" : "json-string"
        } else if (match === "true" || match === "false" || match === "null") {
          cls = "json-literal"
        }
        return `<span class="${cls}">${match}</span>`
      }
    )
  }

  escape(str) {
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }
}
