import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]
  static values = { url: String }

  MAX_LINES = 500

  load() {
    if (this.loaded || !this.element.open) return
    this.loaded = true

    fetch(this.urlValue)
      .then((response) => response.text())
      .then((text) => { this.outputTarget.innerHTML = this.highlight(text) })
      .catch(() => { this.outputTarget.textContent = "読み込みに失敗しました。" })
  }

  highlight(text) {
    const lines = text.split(/\r\n|\n/)
    const truncated = lines.length > this.MAX_LINES
    const shown = truncated ? lines.slice(0, this.MAX_LINES) : lines

    let html = shown.map((line) => this.highlightLine(line)).join("\n")
    if (truncated) {
      html += `\n<span class="ics-continuation">… 以下省略（全${lines.length}行中${this.MAX_LINES}行を表示。全文はダウンロードしてください）</span>`
    }
    return html
  }

  highlightLine(line) {
    if (line === "") return ""

    if (/^[ \t]/.test(line)) {
      return `<span class="ics-continuation">${this.escape(line)}</span>`
    }

    const idx = line.indexOf(":")
    if (idx === -1) return this.escape(line)

    const left = line.slice(0, idx)
    const value = line.slice(idx + 1)
    const [ prop, ...params ] = left.split(";")
    const propClass = (prop === "BEGIN" || prop === "END") ? "ics-keyword" : "ics-prop"

    let html = `<span class="${propClass}">${this.escape(prop)}</span>`
    params.forEach((param) => { html += `;<span class="ics-param">${this.escape(param)}</span>` })
    html += `:<span class="ics-value">${this.escape(value)}</span>`
    return html
  }

  escape(str) {
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }
}
