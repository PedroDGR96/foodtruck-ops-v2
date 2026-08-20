import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.startY = 0
    this.pulling = false
    this.triggered = false
    this.el.addEventListener("touchstart", this.onTouchStart.bind(this), { passive: true })
    this.el.addEventListener("touchmove", this.onTouchMove.bind(this), { passive: false })
    this.el.addEventListener("touchend", this.onTouchEnd.bind(this), { passive: true })
  }

  disconnect() {
    this.el.removeEventListener("touchstart", this.onTouchStart)
    this.el.removeEventListener("touchmove", this.onTouchMove)
    this.el.removeEventListener("touchend", this.onTouchEnd)
  }

  onTouchStart(e) {
    if (window.scrollY === 0) {
      this.startY = e.touches[0].clientY
      this.pulling = true
      this.triggered = false
    }
  }

  onTouchMove(e) {
    if (!this.pulling) return
    const dy = e.touches[0].clientY - this.startY
    if (dy > 0 && dy < 150) {
      this.el.style.transform = `translateY(${dy * 0.4}px)`
      if (dy > 80 && !this.triggered) {
        this.triggered = true
        if (navigator.vibrate) navigator.vibrate(15)
      }
    }
  }

  onTouchEnd() {
    if (!this.pulling) return
    this.pulling = false
    this.el.style.transform = ""
    if (this.triggered) {
      window.location.reload()
    }
  }
}
