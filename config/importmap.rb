# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "codemirror_theme"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@codemirror/view", to: "@codemirror--view.js" # @6.41.0
pin "@codemirror/state", to: "@codemirror--state.js" # @6.6.0
pin "@marijn/find-cluster-break", to: "@marijn--find-cluster-break.js" # @1.0.2
pin "crelt" # @1.0.6
pin "style-mod" # @4.1.3
pin "w3c-keyname" # @2.2.8
pin "@codemirror/language", to: "@codemirror--language.js" # @6.12.3
pin "@lezer/common", to: "@lezer--common.js" # @1.5.1
pin "@lezer/highlight", to: "@lezer--highlight.js" # @1.2.3
pin "@codemirror/commands", to: "@codemirror--commands.js" # @6.10.3
pin "@codemirror/legacy-modes/mode/ruby", to: "@codemirror--legacy-modes--mode--ruby.js" # @6.5.2
