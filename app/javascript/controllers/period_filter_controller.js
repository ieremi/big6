import { Controller } from "@hotwired/stimulus"

const ORDER = ["5", "10", "20", "all"]
const KEY_TO_PERIOD = { s: "5", m: "10", l: "20", a: "all", r: "r" }
const KEY_TO_METRIC = { w: "rate", p: "attendance" }

export default class extends Controller {
  static targets = ["cell", "rowAvg", "rowSum", "button", "metricButton", "periodPanel", "gameRow", "gameCount", "statCell"]
  static values = {
    period: { type: String, default: "all" },
    metric: { type: String, default: "rate" }
  }

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    window.addEventListener("keydown", this.boundKeydown)
    this.render()
    this.hasConnected = true
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundKeydown)
  }

  handleKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return

    if (KEY_TO_PERIOD[event.key]) {
      this.periodValue = KEY_TO_PERIOD[event.key]
    } else if (KEY_TO_METRIC[event.key]) {
      this.metricValue = KEY_TO_METRIC[event.key]
    } else if (event.key === "<") {
      this.step(1)
    } else if (event.key === ">") {
      this.step(-1)
    }
  }

  step(direction) {
    const index = ORDER.indexOf(this.periodValue)
    const nextIndex = Math.min(Math.max(index + direction, 0), ORDER.length - 1)
    this.periodValue = ORDER[nextIndex]
  }

  setPeriod(event) {
    this.periodValue = event.currentTarget.dataset.period
  }

  setMetric(event) {
    this.metricValue = event.currentTarget.dataset.metric
  }

  // The value attribute a "rowAvg"/"rowSum" element carries: each such element
  // already represents a single aggregate (avg or sum), so only metric+period matter.
  metricAttr() {
    return this.metricValue === "attendance" ? `data-attendance-${this.periodValue}` : `data-rate-${this.periodValue}`
  }

  sortByColumn(event) {
    const header = event.currentTarget
    const cellIndex = parseInt(header.dataset.cellIndex, 10)
    const kind = header.dataset.sortKind
    const tbody = this.element.querySelector("tbody")
    const rows = Array.from(tbody.querySelectorAll("tr"))

    const valueFor = (row) => {
      const cell = row.children[cellIndex]
      const el = cell && cell.querySelector("[data-period-filter-target]")
      if (!el) return null

      let attr
      if (el.dataset.periodFilterTarget === "cell") {
        if (this.metricValue === "attendance") {
          attr = kind === "sum" ? `data-attendance-sum-${this.periodValue}` : `data-attendance-avg-${this.periodValue}`
        } else {
          attr = `data-rate-${this.periodValue}`
        }
      } else {
        attr = this.metricAttr()
      }

      const raw = el.getAttribute(attr)
      const num = parseFloat(String(raw).replace(/,/g, ""))
      return Number.isNaN(num) ? null : num
    }

    const direction = header.dataset.sortDirection === "desc" ? "asc" : "desc"

    rows.sort((a, b) => {
      const va = valueFor(a)
      const vb = valueFor(b)
      if (va === null && vb === null) return 0
      if (va === null) return 1
      if (vb === null) return -1
      return direction === "desc" ? vb - va : va - vb
    })

    rows.forEach((row) => tbody.appendChild(row))

    this.element.querySelectorAll("th.sortable").forEach((th) => {
      th.classList.remove("sorted-asc", "sorted-desc")
      delete th.dataset.sortDirection
    })
    header.dataset.sortDirection = direction
    header.classList.add(direction === "desc" ? "sorted-desc" : "sorted-asc")
  }

  periodValueChanged() {
    this.render()
    if (this.hasConnected) this.updateUrl()
  }

  updateUrl() {
    const url = new URL(window.location.href)
    url.searchParams.set("period", this.periodValue)
    window.history.replaceState({}, "", url)
  }

  metricValueChanged() {
    this.render()
  }

  render() {
    this.cellTargets.forEach((el) => {
      if (this.metricValue === "attendance") {
        const avg = el.getAttribute(`data-attendance-avg-${this.periodValue}`) || "—"
        const sum = el.getAttribute(`data-attendance-sum-${this.periodValue}`) || "—"
        el.innerHTML = `<span class="cell-line">平均: ${avg}</span><span class="cell-line">合計: ${sum}</span>`
      } else {
        el.textContent = el.getAttribute(`data-rate-${this.periodValue}`) || "—"
      }
    })

    const metricAttr = this.metricAttr()

    this.rowAvgTargets.forEach((el) => {
      el.textContent = el.getAttribute(metricAttr) || "—"
    })

    this.rowSumTargets.forEach((el) => {
      el.textContent = el.getAttribute(metricAttr) || "—"
    })

    this.buttonTargets.forEach((el) => {
      el.classList.toggle("active", el.dataset.period === this.periodValue)
    })

    this.metricButtonTargets.forEach((el) => {
      el.classList.toggle("active", el.dataset.metric === this.metricValue)
    })

    this.periodPanelTargets.forEach((el) => {
      el.hidden = el.dataset.period !== this.periodValue
    })

    if (this.hasGameRowTarget) {
      let visibleCount = 0
      this.gameRowTargets.forEach((el) => {
        const periods = (el.dataset.periods || "").split(" ")
        const visible = periods.includes(this.periodValue)
        el.hidden = !visible
        if (visible) visibleCount++
      })

      this.gameCountTargets.forEach((el) => {
        el.textContent = `${visibleCount}試合`
      })
    }

    this.statCellTargets.forEach((el) => {
      el.textContent = el.getAttribute(`data-value-${this.periodValue}`) || "—"
    })

    const ogPreview = document.querySelector(".og-preview")
    if (ogPreview) {
      const url = new URL(ogPreview.src, window.location.href)
      url.searchParams.set("period", this.periodValue)
      ogPreview.src = url.toString()
    }
  }
}
