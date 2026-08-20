import { Controller } from "@hotwired/stimulus"

// Dark mode toggle + theme picker. Persists choices in localStorage and
// respects system preference until the user opts in/out explicitly.
export default class extends Controller {
  static targets = ["toggle"]
  static values = { theme: String }

  connect() {
    this.applyTheme()
    this.applyDark()
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
      if (!localStorage.getItem("darkMode")) this.applyDark()
    })
  }

  toggleDark() {
    const dark = document.documentElement.classList.contains("dark")
    localStorage.setItem("darkMode", dark ? "light" : "dark")
    this.applyDark()
  }

  setTheme(event) {
    const theme = event.currentTarget.dataset.theme
    localStorage.setItem("theme", theme)
    this.applyTheme()
  }

  applyTheme() {
    const stored = localStorage.getItem("theme") || "laranja"
    document.documentElement.setAttribute("data-theme", stored)
    // Update theme picker button dots if present
    document.querySelectorAll("[data-theme-dot]").forEach((dot) => {
      dot.classList.toggle("ring-2", dot.dataset.themeDot === stored)
      dot.classList.toggle("ring-offset-2", dot.dataset.themeDot === stored)
    })
  }

  applyDark() {
    const stored = localStorage.getItem("darkMode")
    const dark = stored ? stored === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches
    document.documentElement.classList.toggle("dark", dark)
    this.toggleTargets.forEach((el) => (el.dataset.dark = String(dark)))
  }
}
