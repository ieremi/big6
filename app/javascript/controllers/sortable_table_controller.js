import { Controller } from "@hotwired/stimulus"

// Sorts a table in the browser by the column whose heading was clicked (or whose
// shortcut key was pressed): a click on the column it is sorted by reverses it.
// Put the controller on the <table>, and data-action="sortable-table#sort" (with
// data-sortable-table-first-param, "asc" or "desc", for the first click) on a
// button in each heading.
//
// A cell sorts by its data-sort-value when it has one, else by its text; numbers
// compare as numbers, and blanks ("", "-", "---") go last whichever way it is
// sorted. Rows equal in the column stay in the order they were in. A row marked
// data-sort-fixed (a totals row) stays at the bottom.
export default class extends Controller {
  sort(event) {
    const heading = event.currentTarget.closest("th")
    const column = heading.cellIndex
    const current = heading.classList.contains("sorted-asc") ? "asc" : (heading.classList.contains("sorted-desc") ? "desc" : null)
    const direction = current ? (current === "asc" ? "desc" : "asc") : (event.params.first || "asc")

    this.markHeading(heading, direction)

    const body = this.element.tBodies[0]
    const rows = Array.from(body.rows)
    const fixed = rows.filter((row) => row.hasAttribute("data-sort-fixed"))
    const sign = direction === "asc" ? 1 : -1

    rows
      .filter((row) => !fixed.includes(row))
      .map((row, index) => ({ row, index, value: this.valueOf(row, column) }))
      .sort((a, b) => this.compare(a.value, b.value, sign) || a.index - b.index)
      .forEach(({ row }) => body.insertBefore(row, fixed[0] || null))
  }

  markHeading(heading, direction) {
    this.element.querySelectorAll("th.sortable").forEach((th) => {
      th.classList.remove("sorted-asc", "sorted-desc")
      th.removeAttribute("aria-sort")
    })
    heading.classList.add(direction === "asc" ? "sorted-asc" : "sorted-desc")
    heading.setAttribute("aria-sort", direction === "asc" ? "ascending" : "descending")
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
