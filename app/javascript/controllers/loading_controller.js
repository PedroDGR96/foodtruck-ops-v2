import { Controller } from "@hotwired/stimulus"

// Toggles `is-loading` on <body> while Turbo navigates or a form submits,
// dimming any elements marked with data-loading-target. The Turbo progress
// bar is already rendered by turbo-rails automatically.
export default class extends Controller {
  connect() {
    this.beforeFetchHandler = (event) => this.show(event)
    this.afterFetchHandler = (event) => this.hide(event)
    this.submitEndHandler = (event) => this.hide(event)

    document.addEventListener("turbo:before-fetch-request", this.beforeFetchHandler)
    document.addEventListener("turbo:before-fetch-response", this.afterFetchHandler)
    document.addEventListener("turbo:submit-end", this.submitEndHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-fetch-request", this.beforeFetchHandler)
    document.removeEventListener("turbo:before-fetch-response", this.afterFetchHandler)
    document.removeEventListener("turbo:submit-end", this.submitEndHandler)
  }

  show(event) {
    document.body.classList.add("is-loading")
  }

  hide(event) {
    document.body.classList.remove("is-loading")
  }
}
