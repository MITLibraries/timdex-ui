import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    event.preventDefault()
    
    const isCurrentlyOn = this.element.classList.contains('toggled-on')
    const newState = isCurrentlyOn ? 'false' : 'true'
    
    this.setOptinState(newState)
  }

  setOptinState(state) {
    // Build the redirect URL to return to the current results page
    const redirectUrl = window.location.pathname + window.location.search
    
    // Make a GET request to the toggle endpoint
    const url = new URL('/natural_language_search_optin', window.location.origin)
    url.searchParams.set('natural_language_search_optin', state)
    url.searchParams.set('return_to', redirectUrl)
    
    // Navigate to the toggle URL, which will redirect back with the new cookie set
    window.location.href = url.toString()
  }
}
