import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // A JSON endpoint's box has output/details for the response text. An image
  // endpoint's box has instead a preview <img> (inside previewLink, hidden until
  // there is an image) and a message line, and never shows response text.
  static targets = ["path", "output", "details", "preview", "previewLink", "message"]
  static values = { prefix: String }

  async run() {
    const path = this.pathTarget.value.trim()
    if (!path) return

    if (this.hasPreviewTarget) {
      await this.runForImage(path)
      return
    }

    this.detailsTarget.open = true
    this.outputTarget.textContent = "読み込み中…"

    const url = this.prefixValue + path

    try {
      const response = await fetch(url, { headers: { Accept: "application/json, image/*;q=0.9" } })
      const header = `HTTP ${response.status}\n\n`

      // An image at a path typed into a JSON box: show it rather than its bytes.
      if ((response.headers.get("content-type") || "").startsWith("image/")) {
        await this.showImageInOutput(response, header)
        return
      }

      const text = await response.text()

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

  // An image box shows the image, and only says something while loading or
  // when there is no image to show.
  async runForImage(path) {
    this.showMessage("読み込み中…")

    try {
      const response = await fetch(this.prefixValue + path, { headers: { Accept: "image/*, application/json;q=0.5" } })

      if (!(response.headers.get("content-type") || "").startsWith("image/")) {
        this.previewLinkTarget.hidden = true
        this.showMessage(`画像を取得できませんでした（HTTP ${response.status}）`)
        return
      }

      const blob = await response.blob()
      this.replaceImageUrl(URL.createObjectURL(blob))
      this.previewTarget.src = this.imageUrl
      this.previewLinkTarget.href = this.imageUrl
      this.previewLinkTarget.hidden = false
      this.showMessage("")
    } catch (error) {
      this.previewLinkTarget.hidden = true
      this.showMessage(`リクエストに失敗しました: ${error.message}`)
    }
  }

  showMessage(text) {
    if (!this.hasMessageTarget) return

    this.messageTarget.textContent = text
    this.messageTarget.hidden = text === ""
  }

  async showImageInOutput(response, header) {
    const blob = await response.blob()
    this.replaceImageUrl(URL.createObjectURL(blob))

    const image = document.createElement("img")
    image.src = this.imageUrl
    image.alt = "レスポンスの画像"
    image.className = "sandbox-image"

    this.outputTarget.textContent = `${header}${blob.type}（${Math.round(blob.size / 1024)}KB）\n`
    this.outputTarget.appendChild(image)
  }

  // Object URLs hold their image in memory until revoked, so keep just the latest.
  replaceImageUrl(url) {
    if (this.imageUrl) URL.revokeObjectURL(this.imageUrl)
    this.imageUrl = url
  }

  disconnect() {
    if (this.imageUrl) URL.revokeObjectURL(this.imageUrl)
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
