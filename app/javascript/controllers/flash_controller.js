import { Controller } from "@hotwired/stimulus"

// Dismissible toast for flash messages. Auto-hides after a timeout unless
// hovered. Values: <timeout-ms>.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 6000 } }

  connect() {
    if (this.timeoutValue > 0) {
      this.hideTimer = window.setTimeout(() => this.hide(), this.timeoutValue)
    }
  }

  disconnect() {
    window.clearTimeout(this.hideTimer)
  }

  mouseover() {
    window.clearTimeout(this.hideTimer)
  }

  mouseleave() {
    this.hideTimer = window.setTimeout(() => this.hide(), 2000)
  }

  hide() {
    this.element.remove()
  }
}
