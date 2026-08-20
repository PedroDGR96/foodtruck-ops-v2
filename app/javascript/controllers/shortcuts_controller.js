import { Controller } from "@hotwired/stimulus"

// Global keyboard shortcut plumbing for the POS. Any element with a
// data-shortcut attribute declares comma-separated combos (e.g. "mod+k", "/").
// When a combo is pressed, the element is clicked. If data-shortcut-focus is
// present it is used as a CSS selector for the element to focus instead.
export default class extends Controller {
  connect() {
    this.listener = (event) => this.invoke(event)
    window.addEventListener("keydown", this.listener)
  }

  disconnect() {
    window.removeEventListener("keydown", this.listener)
  }

  invoke(event) {
    if (event.defaultPrevented) return

    const target = this.element.querySelector("[data-shortcut]")
    const candidates = this.element.querySelectorAll("[data-shortcut]")
    for (const el of candidates) {
      const combos = (el.dataset.shortcut || "").split(",").map((c) => c.trim()).filter(Boolean)
      if (combos.some((combo) => this.matches(event, combo))) {
        event.preventDefault()
        const focusSelector = el.dataset.shortcutFocus
        if (focusSelector) {
          const focusTarget = el.querySelector(focusSelector) || document.querySelector(focusSelector)
          focusTarget?.focus()
        } else {
          el.click()
        }
        return
      }
    }
  }

  matches(event, combo) {
    const parts = combo.toLowerCase().split("+").map((p) => p.trim())
    const key = parts.pop()
    if (event.key.toLowerCase() !== key) return false
    if (parts.includes("mod") && !(event.metaKey || event.ctrlKey)) return false
    if (parts.includes("ctrl") && !event.ctrlKey) return false
    if (parts.includes("alt") && !event.altKey) return false
    if (parts.includes("shift") && !event.shiftKey) return false
    return true
  }
}
