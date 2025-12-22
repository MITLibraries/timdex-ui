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
        this.element.innerHTML = html;
        // Hide primo links if libkey link is present
        if (this.element.querySelector('.libkey-link')) {
          const resultGet = this.element.closest('.result-get');
          if (resultGet) {
            const primoLinks = resultGet.querySelectorAll('.primo-link');
            primoLinks.forEach(link => link.style.display = 'none');
          }
        }
      })
  }
}
