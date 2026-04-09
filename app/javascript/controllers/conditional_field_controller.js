import { Controller } from "@hotwired/stimulus"

// Toggles field visibility based on a select value.
//
// "field" targets are hidden when value matches hideWhen.
// "show" targets are revealed when value matches showWhen.
//
// Usage:
//   <div data-controller="conditional-field"
//        data-conditional-field-hide-when-value="any"
//        data-conditional-field-show-when-value="regex">
//     <select data-conditional-field-target="select" data-action="conditional-field#toggle">
//     <div data-conditional-field-target="field">...hidden when "any"...</div>
//     <div data-conditional-field-target="show">...shown when "regex"...</div>
export default class extends Controller {
  static targets = ["select", "field", "show"]
  static values = { hideWhen: String, showWhen: String }

  connect() {
    this.toggle()
  }

  toggle() {
    const value = this.selectTarget.value

    if (this.hasHideWhenValue) {
      const hidden = value === this.hideWhenValue
      this.fieldTargets.forEach(el => el.classList.toggle("hidden", hidden))
    }

    if (this.hasShowWhenValue) {
      const visible = value === this.showWhenValue
      this.showTargets.forEach(el => el.classList.toggle("hidden", !visible))
    }
  }
}
