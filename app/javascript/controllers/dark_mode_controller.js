import { Controller } from "@hotwired/stimulus"

// Dark mode toggle + theme picker. Persists choices in localStorage and
// respects system preference until the user opts in/out explicitly.
// Each named theme is a full look: an accent palette plus a default
// surface mode (light or dark). Picking a dark-named theme (e.g.
// "Midnight") also switches the app to dark mode.
const THEME_MODES = {
  laranja: "light",
  oceano: "light",
  verde: "light",
  sunset: "light",
  midnight: "dark",
  roxo: "dark",
  floresta: "dark",
  brasa: "dark"
}

const THEME_COLORS = {
  laranja: "bg-amber-500",
  oceano: "bg-sky-500",
  verde: "bg-emerald-500",
  sunset: "bg-rose-500",
  midnight: "bg-indigo-500",
  roxo: "bg-violet-500",
  floresta: "bg-teal-500",
  brasa: "bg-orange-600"
}

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
    // Named dark themes switch the surface mode along with the accent.
    if (THEME_MODES[theme]) localStorage.setItem("darkMode", THEME_MODES[theme])
    this.applyTheme()
    this.applyDark()
  }

  applyTheme() {
    const stored = localStorage.getItem("theme") || "laranja"
    document.documentElement.setAttribute("data-theme", stored)
    // Toggle button swatch reflects the current theme's accent
    const swatch = document.querySelector("[data-theme-current-dot]")
    if (swatch) {
      swatch.classList.remove(...Object.values(THEME_COLORS))
      swatch.classList.add(THEME_COLORS[stored] || THEME_COLORS.laranja)
    }
    // Active ring on picker items
    document.querySelectorAll("[data-theme-dot]").forEach((dot) => {
      const active = dot.dataset.themeDot === stored
      dot.classList.toggle("ring-2", active)
      dot.classList.toggle("ring-offset-2", active)
    })
  }

  applyDark() {
    const stored = localStorage.getItem("darkMode")
    const dark = stored ? stored === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches
    document.documentElement.classList.toggle("dark", dark)
    this.toggleTargets.forEach((el) => (el.dataset.dark = String(dark)))
  }
}