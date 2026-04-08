import { Controller } from "@hotwired/stimulus"
import { EditorView, keymap, lineNumbers, highlightActiveLine, highlightSpecialChars, drawSelection, rectangularSelection } from "@codemirror/view"
import { EditorState } from "@codemirror/state"
import { StreamLanguage, bracketMatching, indentOnInput, syntaxHighlighting } from "@codemirror/language"
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands"
import { ruby } from "@codemirror/legacy-modes/mode/ruby"
import { botburrowHighlightStyle } from "codemirror_theme"

// Dark theme matching the BotBurrow dashboard design tokens.
const botburrowTheme = EditorView.theme({
  "&": {
    backgroundColor: "#0f1117",
    color: "#e2e4ed",
    fontSize: "14px",
    borderRadius: "0.375rem",
    border: "1px solid #2e3348"
  },
  "&.cm-focused": {
    outline: "none",
    borderColor: "#6d8cf0",
    boxShadow: "0 0 0 1px #6d8cf0"
  },
  ".cm-content": {
    caretColor: "#6d8cf0",
    fontFamily: "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace",
    padding: "8px 0",
    minHeight: "7.5em"
  },
  ".cm-cursor, .cm-dropCursor": {
    borderLeftColor: "#6d8cf0"
  },
  ".cm-selectionBackground, ::selection": {
    backgroundColor: "#2e3348"
  },
  "&.cm-focused .cm-selectionBackground": {
    backgroundColor: "#2e3348"
  },
  ".cm-activeLine": {
    backgroundColor: "#1a1d27"
  },
  ".cm-gutters": {
    backgroundColor: "#0f1117",
    color: "#5c6178",
    border: "none",
    borderRight: "1px solid #2e3348"
  },
  ".cm-activeLineGutter": {
    backgroundColor: "#1a1d27",
    color: "#8b90a5"
  },
  ".cm-lineNumbers .cm-gutterElement": {
    padding: "0 8px 0 16px"
  },
  ".cm-matchingBracket": {
    backgroundColor: "#2e3348",
    color: "#6d8cf0",
    outline: "1px solid #3d4463"
  },
  ".cm-nonmatchingBracket": {
    color: "#f87171"
  },
  ".cm-scroller": {
    overflow: "auto"
  }
}, { dark: true })

// Stimulus controller: progressively enhances a <textarea> with CodeMirror 6.
// If JS fails to load, the textarea still works for form submission.
export default class extends Controller {
  static targets = ["textarea"]

  connect() {
    // Defer initialization if the element is hidden (e.g., script editor panel
    // not yet visible). CodeMirror needs visible dimensions to render correctly.
    // The MutationObserver watches for the parent becoming visible and inits then.
    if (!this.element.offsetParent) {
      this._observer = new MutationObserver(() => {
        if (this.element.offsetParent) {
          this._observer.disconnect()
          this._observer = null
          this._initEditor()
        }
      })
      this._observer.observe(this.element.closest("[class*='hidden']") || document.body, {
        attributes: true, attributeFilter: ["class"]
      })
      return
    }

    this._initEditor()
  }

  _initEditor() {
    const textarea = this.textareaTarget
    const initialValue = textarea.value || ""

    // Sync editor content back to the textarea on every change so form
    // submission always has the current value.
    const syncToTextarea = EditorView.updateListener.of((update) => {
      if (update.docChanged) {
        textarea.value = update.state.doc.toString()
      }
    })

    const state = EditorState.create({
      doc: initialValue,
      extensions: [
        lineNumbers(),
        highlightActiveLine(),
        highlightSpecialChars(),
        history(),
        drawSelection(),
        rectangularSelection(),
        bracketMatching(),
        indentOnInput(),
        StreamLanguage.define(ruby),
        syntaxHighlighting(botburrowHighlightStyle),
        botburrowTheme,
        keymap.of([
          indentWithTab,
          ...defaultKeymap,
          ...historyKeymap
        ]),
        syncToTextarea,
        EditorView.lineWrapping
      ]
    })

    this.editorView = new EditorView({
      state,
      parent: textarea.parentElement
    })

    // Hide the textarea but keep it in the DOM for form submission.
    textarea.style.display = "none"
  }

  disconnect() {
    if (this._observer) {
      this._observer.disconnect()
      this._observer = null
    }

    if (this.editorView) {
      this.editorView.destroy()
      this.editorView = null
    }

    // Restore the textarea visibility for Turbo navigation.
    this.textareaTarget.style.display = ""
  }
}
