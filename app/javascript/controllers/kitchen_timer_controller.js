import { Controller } from "@hotwired/stimulus"

// Counts kitchen prep time up every second and flags the ticket as overdue
// once it passes the configured threshold. Overdue toggles a class on the
// ticket root so it is easy to target in Tailwind/CSS.
export default class extends Controller {
  static values = { start: Number, overdueAfter: Number }
  static targets = ["elapsed", "overdue"]

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const elapsed = Math.max(0, Math.floor((Date.now() - this.startValue) / 1000))
    if (this.hasElapsedTarget) {
      this.elapsedTarget.textContent = this.format(elapsed)
    }
    if (elapsed >= this.overdueAfterValue) {
      this.element.classList.add("is-overdue")
      if (this.hasOverdueTarget) {
        this.overdueTarget.hidden = false
      }
    }
  }

  format(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${String(secs).padStart(2, "0")}`
  }
}
