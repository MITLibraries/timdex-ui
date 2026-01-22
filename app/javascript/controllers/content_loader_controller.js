import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.load()
  }

  load() {
    fetch(this.urlValue)
      .then(response => response.text())
      .then(html => {
        const parentElement = this.element.parentElement;
        // Replace the entire element with the fetched HTML
        this.element.outerHTML = html;
        // Hide primo links if libkey link is present
        if (parentElement.querySelector('.libkey-link')) {
          const resultGet = parentElement.closest('.result-get');
          if (resultGet) {
            const primoLinks = resultGet.querySelectorAll('.primo-link');
            // removing instead of hiding to avoid layout issues when selecting which link to highlight
            primoLinks.forEach(link => link.remove());
          }
        }
      })
  }
}
