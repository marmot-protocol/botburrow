import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "overlay"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    this.overlayTarget.classList.toggle("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.overlayTarget.classList.add("hidden")
  }
}
