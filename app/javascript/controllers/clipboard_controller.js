import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue)
    const button = this.element.querySelector("button")
    const original = button.innerHTML
    button.innerHTML = "&#10003;"
    setTimeout(() => button.innerHTML = original, 1500)
  }
}
