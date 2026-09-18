import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["universityCheckbox", "termCheckbox", "yearInput", "universityModeButton", "universityModeInput"]

  submit() {
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
