import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["credentials", "testResult"]

  toggleProvider(event) {
    const checkbox = event.target
    const provider = checkbox.dataset.provider || checkbox.closest("[data-provider]")?.dataset.provider
    const label = checkbox.nextElementSibling?.nextElementSibling

    if (label) {
      label.textContent = checkbox.checked ? "Ativado" : "Desativado"
    }

    // Update status dot in sidebar
    const sidebarLink = document.querySelector(`a[href="#${provider}"] span`)
    if (sidebarLink) {
      if (checkbox.checked) {
        sidebarLink.className = "flex h-6 w-6 items-center justify-center rounded-full text-xs bg-emerald-100 text-emerald-700 dark:bg-emerald-900 dark:text-emerald-300"
        sidebarLink.textContent = "✓"
      } else {
        sidebarLink.className = "flex h-6 w-6 items-center justify-center rounded-full text-xs bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-400"
        sidebarLink.textContent = "—"
      }
    }
  }

  async testConnection(event) {
    const button = event.currentTarget
    const provider = button.dataset.provider
    const resultTarget = this.testResultTargets.find(t => t.dataset.provider === provider)

    button.disabled = true
    button.innerHTML = `<svg class="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg> Testando...`

    try {
      const response = await fetch(`/integrations/test/${provider}`, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
          "Content-Type": "application/json"
        }
      })

      const data = await response.json()

      if (resultTarget) {
        resultTarget.classList.remove("hidden")
        if (data.success) {
          resultTarget.className = "text-sm text-emerald-600 dark:text-emerald-400"
          resultTarget.textContent = "✓ Conectado"
        } else {
          resultTarget.className = "text-sm text-red-600 dark:text-red-400"
          resultTarget.textContent = `✗ ${data.message || "Erro ao conectar"}`
        }
      }
    } catch (error) {
      if (resultTarget) {
        resultTarget.classList.remove("hidden")
        resultTarget.className = "text-sm text-red-600 dark:text-red-400"
        resultTarget.textContent = "✗ Erro de conexão"
      }
    } finally {
      button.disabled = false
      button.innerHTML = `<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg> Testar Conexão`
    }
  }
}
