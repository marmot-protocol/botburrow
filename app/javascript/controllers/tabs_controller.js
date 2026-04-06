import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const selected = event.currentTarget.dataset.tabsId

    this.tabTargets.forEach(tab => {
      const active = tab.dataset.tabsId === selected
      tab.classList.toggle("border-primary", active)
      tab.classList.toggle("text-text", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("text-text-muted", !active)
    })

    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.id !== selected)
    })
  }
}
