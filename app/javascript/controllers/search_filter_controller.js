import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["universityCheckbox", "termCheckbox", "yearInput"]

  submit() {
    this.element.requestSubmit()
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
