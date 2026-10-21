import { Controller } from "@hotwired/stimulus"

// The hover layer of the charts of a line for each university, game by game
// (seasons/_university_line_chart: the title chances and the strengths): a
// vertical line follows the pointer, snapping to the nearest game, with a dot
// on each line and one tooltip giving the game and every university's value.
// With the chart focused, the arrow keys move from game to game. The figures
// come from the data value (built by the server); names go in with textContent.
export default class extends Controller {
  static targets = ["svg", "crosshair", "dot", "tooltip"]
  static values = { data: Object, width: Number, top: Number, height: Number }

  point(event) {
    const rect = this.svgTarget.getBoundingClientRect()
    const x = (event.clientX - rect.left) / rect.width * this.widthValue
    const points = this.dataValue.points
    let nearest = 0
    points.forEach((point, index) => {
      if (Math.abs(point.x - x) < Math.abs(points[nearest].x - x)) nearest = index
    })
    this.show(nearest)
  }

  focus() {
    this.show(this.index ?? this.dataValue.points.length - 1)
  }

  key(event) {
    const step = { ArrowLeft: -1, ArrowRight: 1 }[event.key]
    if (step === undefined) return

    event.preventDefault()
    const last = this.dataValue.points.length - 1
    this.show(Math.min(Math.max((this.index ?? last) + step, 0), last))
  }

  hide() {
    this.crosshairTarget.setAttribute("visibility", "hidden")
    this.dotTargets.forEach((dot) => dot.setAttribute("visibility", "hidden"))
    this.tooltipTarget.hidden = true
  }

  show(index) {
    this.index = index
    const point = this.dataValue.points[index]
    const y = (chance) => this.topValue + this.heightValue - chance * this.heightValue

    this.crosshairTarget.setAttribute("x1", point.x)
    this.crosshairTarget.setAttribute("x2", point.x)
    this.crosshairTarget.setAttribute("visibility", "visible")
    this.dotTargets.forEach((dot) => {
      dot.setAttribute("cx", point.x)
      dot.setAttribute("cy", y(point.values[dot.dataset.slug] || 0))
      dot.setAttribute("visibility", "visible")
    })

    this.renderTooltip(point)
    const share = point.x / this.widthValue
    this.tooltipTarget.style.left = `${share * 100}%`
    this.tooltipTarget.style.transform = share > 0.6 ? "translateX(calc(-100% - 12px))" : "translateX(12px)"
    this.tooltipTarget.hidden = false
  }

  // The game, then a row for each university, highest chance first: the value
  // strong, the name after it, keyed by a short stroke of the university's colour.
  renderTooltip(point) {
    const heading = document.createElement("div")
    heading.className = "line-chart-tooltip-heading"
    heading.textContent = point.label

    const rows = this.dataValue.universities
      .map((university) => ({ ...university, chance: point.values[university.slug] || 0 }))
      .sort((a, b) => b.chance - a.chance)
      .map((university) => {
        const row = document.createElement("div")
        row.className = "line-chart-tooltip-row"
        const key = document.createElement("span")
        key.className = "line-chart-key"
        key.style.background = university.color
        const value = document.createElement("strong")
        value.textContent = `${Number((university.chance * 100).toFixed(1))}%`
        const name = document.createElement("span")
        name.textContent = university.name
        row.append(key, value, name)
        return row
      })

    this.tooltipTarget.replaceChildren(heading, ...rows)
  }
}
