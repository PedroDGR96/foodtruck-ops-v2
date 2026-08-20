import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.btn = document.getElementById("scroll-top")
    this.onScroll = this.check.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.check()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  check() {
    if (!this.btn) return
    this.btn.classList.toggle("hidden", window.scrollY < 300)
    this.btn.classList.toggle("flex", window.scrollY >= 300)
  }

  up() {
    window.scrollTo({ top: 0, behavior: "smooth" })
    if (navigator.vibrate) navigator.vibrate(5)
  }
}
