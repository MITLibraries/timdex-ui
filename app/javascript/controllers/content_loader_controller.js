import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, lazyLoading: Boolean }

  connect() {
    if (this.lazyLoadingValue) {
      // The content loader included a lazy loading directive.
      this.observer = new IntersectionObserver(
        (entries) => {
          if (entries[0].isIntersecting) {
            this.load()
            this.observer.disconnect()
          }
        }
      )
      this.observer.observe(this.element)
    } else {
      // Load the content immediately.
      this.load()
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }

  load() {
    fetch(this.urlValue)
      .then(response => response.text())
      .then(html => {
        const parentElement = this.element.parentElement
        // Replace the entire element with the fetched HTML, or remove if empty
        if (html.trim()) {
          this.element.outerHTML = html

          // Keep Alma availability in `.result-content` but place “Full-text options”
          // with fulfillment links in the descendant `.result-get` container.
          const resultContent = parentElement.closest('.result-content') || parentElement
          const almaFulltextOptions = resultContent.querySelector("[data-action-source='alma'][data-action-type='full_text_options']")
          const resultGet = resultContent.querySelector('.result-get')
          if (almaFulltextOptions && resultGet) {
            const firstLibkeyActions = resultGet.querySelector('.libkey-actions')
            if (firstLibkeyActions) {
              resultGet.insertBefore(almaFulltextOptions, firstLibkeyActions)
            } else {
              resultGet.prepend(almaFulltextOptions)
            }
          }

          // Hide primo links when a fulfillment action explicitly declares it
          // should override Primo fallback actions.
          // Use the result content root so this works for both loaders:
          // - Browzine loader is inside `.result-get`
          // - Alma loader is outside `.result-get`
          const hasPrimoOverrideAction = resultContent.querySelector("[data-overrides-primo='true']")
          if (hasPrimoOverrideAction && resultGet) {
            const primoLinks = resultGet.querySelectorAll("[data-action-source='primo'][data-action-type='primo_link'], [data-action-source='primo'][data-action-type='full_text_options'], [data-action-source='alma'][data-action-type='full_text_options']")
            // Removing instead of hiding avoids layout issues when selecting which link to highlight.
            primoLinks.forEach(link => link.remove())
          }

          // Keep only one full-text options action in the result-get area.
          if (resultGet) {
            const fullTextOptionActions = Array.from(resultGet.querySelectorAll("[data-action-type='full_text_options']"))

            if (fullTextOptionActions.length > 1) {
              const preferredAction = fullTextOptionActions.find((action) => action.dataset.overridesPrimo === 'true') ||
                fullTextOptionActions[0]

              fullTextOptionActions.forEach((action) => {
                if (action !== preferredAction) {
                  action.remove()
                }
              })
            }
          }
        } else {
          // Remove empty loader
          this.element.remove()

          // Remove parent empty container, confirming first that it's empty
          if (!parentElement.textContent.trim()) {
            parentElement.remove()
          }
        }
      })
  }
}
