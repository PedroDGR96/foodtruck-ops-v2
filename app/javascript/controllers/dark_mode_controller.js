import { Controller } from "@hotwired/stimulus"

// Dark mode toggle. Persists the choice in localStorage and respects the
// system preference until the user opts in/out explicitly.
export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.apply()
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
      if (!localStorage.getItem("theme")) this.apply()
    })
  }

  toggle() {
    const dark = document.documentElement.classList.contains("dark")
    localStorage.setItem("theme", dark ? "light" : "dark")
    this.apply()
  }

  apply() {
    const stored = localStorage.getItem("theme")
    const dark = stored ? stored === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches
    document.documentElement.classList.toggle("dark", dark)
    this.toggleTargets.forEach((el) => (el.dataset.dark = String(dark)))
  }
}
