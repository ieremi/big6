import { Controller } from "@hotwired/stimulus"

// Shows one of several views of the same figures, picked with a button for
// each (the strengths as a chance, odds or log odds, seasons/_team_strength):
// a button's data-view names the panel it shows, the others are hidden.
export default class extends Controller {
  static targets = ["button", "panel"]

  select(event) {
    const view = event.currentTarget.dataset.view
    this.buttonTargets.forEach((button) => {
      const active = button.dataset.view === view
      button.classList.toggle("active", active)
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.view !== view })
  }
}
