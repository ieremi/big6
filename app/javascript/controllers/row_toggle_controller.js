import { Controller } from "@hotwired/stimulus"

// Opens and closes the detail rows of a table: the rows marked
// data-sort-with-previous (hidden at first) right after a row, shown and hidden
// by a button in that row with data-action="row-toggle#toggle". openAll and
// closeAll do every row within the controller's element. The button's
// aria-expanded says whether its rows are open.
export default class extends Controller {
  toggle(event) {
    const button = event.currentTarget
    this.setOpen(button, button.getAttribute("aria-expanded") !== "true")
  }

  openAll() {
    this.buttons().forEach((button) => this.setOpen(button, true))
  }

  closeAll() {
    this.buttons().forEach((button) => this.setOpen(button, false))
  }

  buttons() {
    return Array.from(this.element.querySelectorAll("[data-action~='row-toggle#toggle']"))
  }

  setOpen(button, open) {
    button.setAttribute("aria-expanded", open ? "true" : "false")
    let row = button.closest("tr").nextElementSibling
    while (row && row.hasAttribute("data-sort-with-previous")) {
      row.hidden = !open
      row = row.nextElementSibling
    }
  }
}
