import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  vibrate(event) {
    if (navigator.vibrate) {
      navigator.vibrate(10)
    }
  }
}
