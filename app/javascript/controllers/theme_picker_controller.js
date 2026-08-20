import { Controller } from "@hotwired/stimulus"

// Theme picker dropdown. Opens/closes the theme menu and delegates
// theme selection to the dark-mode controller.
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.open = false
  }

  toggle() {
    this.open = !this.open
    this.menuTarget.classList.toggle("hidden", !this.open)
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.open = false
      this.menuTarget.classList.add("hidden")
    }
  }
}
