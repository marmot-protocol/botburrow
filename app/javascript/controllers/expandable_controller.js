import { Controller } from "@hotwired/stimulus"

// Toggles between short and full content on click.
//
// Usage:
//   <div data-controller="expandable" data-action="click->expandable#toggle" class="cursor-pointer">
//     <span data-expandable-target="short">Truncated...</span>
//     <span data-expandable-target="full" class="hidden">Full content here</span>
//   </div>
export default class extends Controller {
  static targets = ["short", "full"]

  toggle() {
    this.shortTarget.classList.toggle("hidden")
    this.fullTarget.classList.toggle("hidden")
  }
}
