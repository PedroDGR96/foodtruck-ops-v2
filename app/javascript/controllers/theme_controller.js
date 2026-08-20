import { Controller } from "@hotwired/stimulus"

const THEMES = ["orange", "indigo", "emerald", "rose"]
const STORAGE_KEY = "foodtruck-theme"

export default class extends Controller {
  static targets = ["dot"]

  connect() {
    const saved = localStorage.getItem(STORAGE_KEY) || "orange"
    this.apply(saved)
  }

  select(event) {
    const theme = event.currentTarget.dataset.theme
    this.apply(theme)
    localStorage.setItem(STORAGE_KEY, theme)
  }

  apply(theme) {
    document.documentElement.setAttribute("data-theme", theme)

    this.dotTargets.forEach(dot => {
      if (dot.dataset.theme === theme) {
        dot.classList.add("active")
      } else {
        dot.classList.remove("active")
      }
    })
  }
}
