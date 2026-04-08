import { Controller } from "@hotwired/stimulus"

// Toggles between a standard textarea and a script editor based on the
// selected response_type or action_type. Used by command, trigger, and
// scheduled action forms.
//
// When script is selected, the form expands to a two-column layout:
// left column has the config fields, right column has the script editor.
//
// Hidden panels have their inputs disabled so duplicate-named fields
// (e.g., two response_text textareas) don't conflict on form submission.
export default class extends Controller {
  static targets = ["select", "standardField", "scriptField", "formPanel", "editorPanel"]

  connect() {
    this.toggle()
  }

  toggle() {
    const isScript = this.selectTarget.value === "script"

    this.standardFieldTargets.forEach(el => {
      el.classList.toggle("hidden", isScript)
      el.querySelectorAll("input, textarea, select").forEach(input => {
        input.disabled = isScript
      })
    })

    this.scriptFieldTargets.forEach(el => {
      el.classList.toggle("hidden", !isScript)
      el.querySelectorAll("input, textarea, select").forEach(input => {
        input.disabled = !isScript
      })
    })

    // Toggle two-column layout on the parent wrapper
    if (this.hasFormPanelTarget && this.hasEditorPanelTarget) {
      const wrapper = this.formPanelTarget.parentElement
      wrapper.classList.toggle("grid", isScript)
      wrapper.classList.toggle("lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]", isScript)
      wrapper.classList.toggle("gap-6", isScript)
      this.editorPanelTarget.classList.toggle("hidden", !isScript)
      this.editorPanelTarget.querySelectorAll("textarea").forEach(input => {
        input.disabled = !isScript
      })
    }
  }
}
