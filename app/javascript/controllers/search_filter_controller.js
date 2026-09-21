import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "universityCheckbox", "termCheckbox", "yearInput", "universityModeButton", "universityModeInput",
    "activeOnlyButton", "activeOnlyInput", "statusSelect", "activeStatusButton"
  ]

  // Submits the form: on a change of any of its fields, except one that marks itself
  // data-manual-submit. That one (a number that is stepped again and again) waits for
  // the form's button, or Enter, since every submit reloads the page.
  submit(event) {
    if (event && event.target && event.target.dataset && event.target.dataset.manualSubmit !== undefined) return

    this.element.requestSubmit()
  }

  setUniversityMode(event) {
    const mode = event.currentTarget.dataset.mode

    this.universityModeInputTarget.value = mode
    this.universityModeButtonTargets.forEach((el) => {
      el.classList.toggle("active", el.dataset.mode === mode)
    })

    this.submit()
  }

  toggleActiveOnly() {
    const active = this.activeOnlyInputTarget.value !== "1"

    this.activeOnlyInputTarget.value = active ? "1" : ""
    this.activeOnlyButtonTarget.classList.toggle("active", active)

    this.submit()
  }

  // A single "現役のみ" toggle over the existing 在籍 select (active/alumni/all),
  // for the players page: unlike rankings' active-only, which has no other
  // status option, this shares its value with that dropdown rather than a
  // separate hidden field.
  toggleActiveStatus() {
    const active = this.statusSelectTarget.value !== "active"

    this.statusSelectTarget.value = active ? "active" : ""
    this.activeStatusButtonTarget.classList.toggle("active", active)

    this.submit()
  }

  checkAllUniversities() {
    this.universityCheckboxTargets.forEach((el) => { el.checked = true })
    this.submit()
  }

  clearUniversities() {
    this.universityCheckboxTargets.forEach((el) => { el.checked = false })
    this.submit()
  }

  checkAllTerms() {
    this.termCheckboxTargets.forEach((el) => { el.checked = true })
    this.submit()
  }

  clearTerms() {
    this.termCheckboxTargets.forEach((el) => { el.checked = false })
    this.submit()
  }

  clearYears() {
    this.yearInputTargets.forEach((el) => { el.value = "" })
    this.submit()
  }
}
