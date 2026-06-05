import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.load()
  }

  stripHtmlComments(input) {
    let previous
    let output = input

    do {
      previous = output
      output = output.replace(/<!--[\s\S]*?-->/g, '')
    } while (output !== previous)

    return output
  }

  load() {
    fetch(this.urlValue)
      .then(response => response.text())
      .then(html => {
        const parentElement = this.element.parentElement
        // Strip HTML comments and trim whitespace
        const cleanedHtml = this.stripHtmlComments(html).trim()
        // Replace the entire element with the fetched HTML, or remove if empty
        if (cleanedHtml) {
          this.element.outerHTML = cleanedHtml
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
          // Remove only this loader element
          this.element.remove();
          // Remove result-get container if it's now empty (no fulfillment links and no other content)
          if (!parentElement.textContent.trim()) {
            parentElement.remove();
          }
        }
      })
  }
}
