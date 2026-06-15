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
          // Hide primo links if libkey link is present
          if (parentElement.querySelector('.libkey-link')) {
            const resultGet = parentElement.closest('.result-get')
            if (resultGet) {
              const primoLinks = resultGet.querySelectorAll('.primo-link')
              // removing instead of hiding to avoid layout issues when selecting which link to highlight
              primoLinks.forEach(link => link.remove())
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
