import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const hash = window.location.hash.replace("#", "")
    if (hash) this.activate(hash)
  }

  select(event) {
    this.activate(event.currentTarget.dataset.tabsId)
  }

  activate(id) {
    const match = this.panelTargets.find(p => p.id === id)
    if (!match) return

    this.tabTargets.forEach(tab => {
      const active = tab.dataset.tabsId === id
      tab.classList.toggle("border-primary", active)
      tab.classList.toggle("text-text", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("text-text-muted", !active)
    })

    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.id !== id)
    })
  }
}
