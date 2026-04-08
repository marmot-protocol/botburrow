import { HighlightStyle } from "@codemirror/language"
import { tags } from "@lezer/highlight"

// Shared syntax highlighting colors for all CodeMirror instances (editable and read-only).
export const botburrowHighlightStyle = HighlightStyle.define([
  { tag: tags.keyword, color: "#c792ea" },
  { tag: tags.atom, color: "#f78c6c" },
  { tag: tags.number, color: "#f78c6c" },
  { tag: tags.string, color: "#c3e88d" },
  { tag: tags.special(tags.string), color: "#89ddff" },
  { tag: tags.comment, color: "#5c6178", fontStyle: "italic" },
  { tag: tags.variableName, color: "#e2e4ed" },
  { tag: tags.special(tags.variableName), color: "#ff5370" },
  { tag: tags.propertyName, color: "#82aaff" },
  { tag: tags.definition(tags.variableName), color: "#82aaff" },
  { tag: tags.operator, color: "#89ddff" },
  { tag: tags.tagName, color: "#ffcb6b" },
  { tag: tags.meta, color: "#8b90a5" }
])
