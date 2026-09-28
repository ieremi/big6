import { Controller } from "@hotwired/stimulus"

// Sorts a table in the browser by up to three columns (並べ替えのキー), the way
// the tables sorted on the server do (SortOrder): a click on a column's heading
// (or its shortcut key) makes it the first key and moves the others down; a
// click on the first key reverses it. Headings show each key's number and
// direction ("1▲", "2▼") once there is more than one, and a 「並べ替えをリセット」
// button, added above the table while it is sorted, puts the rows back in the
// order they came in. Put the controller on the <table>, and
// data-action="sortable-table#sort" (with data-sortable-table-first-param, "asc"
// or "desc", for the first click) on a button in each heading.
//
// A cell sorts by its data-sort-value when it has one, else by its text; numbers
// compare as numbers, and blanks ("", "-", "---") go last whichever way it is
// sorted. Rows equal in every key stay in the order they came in. A row marked
// data-sort-fixed (a totals row) stays at the bottom, and one marked
// data-sort-with-previous (a detail row that opens under its row) isn't sorted
// itself but moves along with the row before it.
const MAX_KEYS = 3

export default class extends Controller {
  connect() {
    this.keys = []
    this.originalOrder = new Map(Array.from(this.element.tBodies[0]?.rows || []).map((row, index) => [ row, index ]))
  }

  disconnect() {
    this.resetButton?.remove()
    this.resetButton = null
  }

  sort(event) {
    const heading = event.currentTarget.closest("th")
    const column = heading.cellIndex

    if (this.keys[0]?.heading === heading) {
      this.keys[0] = { heading, column, direction: this.keys[0].direction === "asc" ? "desc" : "asc" }
    } else {
      const direction = event.params.first || "asc"
      this.keys = [ { heading, column, direction }, ...this.keys.filter((key) => key.heading !== heading) ].slice(0, MAX_KEYS)
    }

    this.arrange()
  }

  reset() {
    this.keys = []
    this.arrange()
  }

  arrange() {
    this.markHeadings()
    this.showResetButton()

    const body = this.element.tBodies[0]
    const rows = Array.from(body.rows)
    const fixed = rows.filter((row) => row.hasAttribute("data-sort-fixed"))

    this.groups(rows.filter((row) => !fixed.includes(row)))
      .map((group) => ({
        group,
        index: this.originalIndex(group[0]),
        values: this.keys.map((key) => this.valueOf(group[0], key.column))
      }))
      .sort((a, b) => this.compareKeys(a.values, b.values) || a.index - b.index)
      .forEach(({ group }) => group.forEach((row) => body.insertBefore(row, fixed[0] || null)))
  }

  // Where a row was when the table was first shown (a row added since goes after those).
  originalIndex(row) {
    if (!this.originalOrder.has(row)) this.originalOrder.set(row, this.originalOrder.size)
    return this.originalOrder.get(row)
  }

  compareKeys(aValues, bValues) {
    for (let i = 0; i < this.keys.length; i++) {
      const result = this.compare(aValues[i], bValues[i], this.keys[i].direction === "asc" ? 1 : -1)
      if (result !== 0) return result
    }
    return 0
  }

  // The rows in groups: each row with the data-sort-with-previous rows after it.
  groups(rows) {
    const groups = []
    rows.forEach((row) => {
      if (row.hasAttribute("data-sort-with-previous") && groups.length > 0) {
        groups[groups.length - 1].push(row)
      } else {
        groups.push([ row ])
      }
    })
    return groups
  }

  markHeadings() {
    this.element.querySelectorAll("th.sortable").forEach((th) => {
      th.classList.remove("sorted-asc", "sorted-desc")
      th.removeAttribute("aria-sort")
      delete th.dataset.sortRank
    })

    this.keys.forEach((key, index) => {
      const heading = key.heading
      heading.classList.add(key.direction === "asc" ? "sorted-asc" : "sorted-desc")
      if (index === 0) heading.setAttribute("aria-sort", key.direction === "asc" ? "ascending" : "descending")
      if (this.keys.length > 1) heading.dataset.sortRank = index + 1
    })
  }

  // The reset button sits just above the table (above its scrolling wrapper, if any).
  showResetButton() {
    if (this.keys.length === 0) {
      this.resetButton?.remove()
      this.resetButton = null
      return
    }
    if (this.resetButton) return

    const button = document.createElement("button")
    button.type = "button"
    button.className = "period-btn sort-reset"
    button.textContent = "並べ替えをリセット"
    button.addEventListener("click", () => this.reset())

    const wrapper = this.element.closest(".table-scroll") || this.element
    wrapper.before(button)
    this.resetButton = button
  }

  // A number, a string, or null when the cell is blank.
  valueOf(row, column) {
    const cell = row.cells[column]
    if (!cell) return null

    const raw = (cell.dataset.sortValue !== undefined ? cell.dataset.sortValue : cell.textContent).trim()
    if (raw === "" || /^[-—–]+$/.test(raw)) return null

    const number = Number(raw)
    return Number.isNaN(number) ? raw : number
  }

  // Negative when a goes first. Blanks last in either direction; numbers before text.
  compare(a, b, sign) {
    if (a === null || b === null) return (a === null ? 1 : 0) - (b === null ? 1 : 0)
    if (typeof a === "number" && typeof b === "number") return (a - b) * sign
    if (typeof a === "number") return -1
    if (typeof b === "number") return 1
    return a.localeCompare(b, "ja", { numeric: true }) * sign
  }
}
