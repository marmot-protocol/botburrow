import { Controller } from "@hotwired/stimulus"
import { EditorView } from "@codemirror/view"
import { EditorState } from "@codemirror/state"
import { StreamLanguage, syntaxHighlighting } from "@codemirror/language"
import { ruby } from "@codemirror/legacy-modes/mode/ruby"
import { botburrowHighlightStyle } from "codemirror_theme"

const theme = EditorView.theme({
  "&": {
    backgroundColor: "#0f1117",
    color: "#e2e4ed",
    fontSize: "12px",
    borderRadius: "0.375rem"
  },
  ".cm-content": {
    fontFamily: "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace",
    padding: "8px 12px"
  },
  ".cm-scroller": { overflow: "auto" },
  ".cm-gutters": { display: "none" },
  "&.cm-focused": { outline: "none" },
  ".cm-activeLine": { backgroundColor: "transparent" },
  ".cm-selectionBackground, ::selection": { backgroundColor: "#2e3348" }
}, { dark: true })

// Read-only CodeMirror instance for syntax-highlighted example snippets.
// Replaces a <pre> element with a non-editable editor.
export default class extends Controller {
  connect() {
    const pre = this.element
    const code = pre.textContent

    const state = EditorState.create({
      doc: code,
      extensions: [
        StreamLanguage.define(ruby),
        syntaxHighlighting(botburrowHighlightStyle),
        theme,
        EditorState.readOnly.of(true),
        EditorView.editable.of(false)
      ]
    })

    const wrapper = document.createElement("div")
    pre.parentElement.insertBefore(wrapper, pre)
    pre.style.display = "none"

    this.editorView = new EditorView({ state, parent: wrapper })
  }

  disconnect() {
    if (this.editorView) {
      this.editorView.parent?.remove()
      this.editorView.destroy()
      this.editorView = null
    }
    this.element.style.display = ""
  }
}
