import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "addressFields", "street", "city", "state"]

  connect() {
    this.toggle()
  }

  toggle() {
    const delivery = this.selectTarget.value === "delivery"
    this.addressFieldsTarget.classList.toggle("hidden", !delivery)
    this.streetTarget.required = delivery
    this.cityTarget.required = delivery
    this.stateTarget.required = delivery
  }
}
