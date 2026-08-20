import { Controller } from "@hotwired/stimulus"

// Plays a short chime when a new ticket lands in the kitchen queue. Sound is
// OFF by default and only activates after the staff member clicks the button:
// that click is the user gesture that unlocks the AudioContext, satisfying the
// browser autoplay policy (no sound before an explicit interaction).
export default class extends Controller {
  static values = { enabled: Boolean, onLabel: String, offLabel: String }
  static targets = ["label"]

  connect() {
    this.enabledValue = false
    this.streamHandler = (event) => this.onStream(event)
    document.addEventListener("turbo:before-stream-render", this.streamHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.streamHandler)
  }

  toggle() {
    this.enabledValue = !this.enabledValue
  }

  enabledValueChanged() {
    if (this.enabledValue) {
      this.unlock()
      this.chime()
    }
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.enabledValue ? this.onLabelValue : this.offLabelValue
    }
    this.element.setAttribute("aria-pressed", String(this.enabledValue))
  }

  onStream(event) {
    if (!this.enabledValue) return
    const stream = event.detail?.render?.element
    if (!stream) return
    const action = stream.getAttribute("action")
    const target = stream.getAttribute("target")
    if ((action === "append" || action === "prepend") && target && target.startsWith("kitchen-queue-")) {
      this.chime()
    }
  }

  unlock() {
    const Ctx = window.AudioContext || window.webkitAudioContext
    if (!Ctx) return
    this.context ||= new Ctx()
    if (this.context.state === "suspended") {
      this.context.resume()
    }
  }

  chime() {
    if (!this.context) return
    const now = this.context.currentTime
    const osc = this.context.createOscillator()
    const gain = this.context.createGain()
    osc.frequency.value = 880
    osc.type = "sine"
    gain.gain.setValueAtTime(0.0001, now)
    gain.gain.exponentialRampToValueAtTime(0.2, now + 0.02)
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.35)
    osc.connect(gain)
    gain.connect(this.context.destination)
    osc.start(now)
    osc.stop(now + 0.4)
  }
}
