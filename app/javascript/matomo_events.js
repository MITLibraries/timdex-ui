/**
 * Matomo Tag Manager Event Dispatcher
 * 
 * Pushes custom events to window._mtm for Tag Manager to capture.
 * This module automatically tracks page views on turbo:load (history changes)
 * and provides helper functions for tracking custom interactions.
 * 
 * Ensures _mtm queue exists and safely pushes event objects for Tag Manager processing.
 */

// Ensure _mtm queue exists
window._mtm = window._mtm || [];

/**
 * Push a custom event object to Matomo Tag Manager queue
 * @param {Object} eventData - Event object with custom properties (e.g., {event: 'search_submitted', query: 'test'})
 */
function pushEvent(eventData) {
  if (!window._mtm) {
    console.warn('Matomo Tag Manager (_mtm) not available');
    return;
  }
  window._mtm.push(eventData);
}

/**
 * Track a page view when URL/history changes (for SPA navigation)
 * Pushes page metadata to Tag Manager for processing
 * @param {string} pageUrl - Current page URL (defaults to window.location.href)
 * @param {string} pageTitle - Page title (defaults to document.title)
 */
export function trackPageView(pageUrl = window.location.href, pageTitle = document.title) {
  pushEvent({
    'event': 'page_view',
    'page_url': pageUrl,
    'page_path': new URL(pageUrl).pathname + new URL(pageUrl).search,
    'page_title': pageTitle,
    'timestamp': new Date().toISOString()
  });
}

/**
 * Track a search submission
 * @param {string} query - Search query text
 * @param {Object} options - Additional event properties (searchType, filters, etc.)
 */
export function trackSearch(query, options = {}) {
  pushEvent({
    'event': 'search_submitted',
    'search_query': query,
    'search_type': options.searchType || 'keyword',
    'timestamp': new Date().toISOString(),
    ...options
  });
}

/**
 * Track a filter change/interaction
 * @param {string} filterName - Name of the filter (e.g., 'language', 'content_type')
 * @param {string|Array} filterValue - Selected filter value(s)
 * @param {string} action - Action type ('applied', 'removed', 'changed')
 */
export function trackFilterChange(filterName, filterValue, action = 'applied') {
  pushEvent({
    'event': 'filter_interaction',
    'filter_name': filterName,
    'filter_value': Array.isArray(filterValue) ? filterValue.join(',') : filterValue,
    'filter_action': action,
    'timestamp': new Date().toISOString()
  });
}

/**
 * Track a tab/source selection change
 * @param {string} tabName - Tab name (e.g., 'primo', 'timdex', 'all')
 */
export function trackTabChange(tabName) {
  pushEvent({
    'event': 'tab_selected',
    'tab_name': tabName,
    'timestamp': new Date().toISOString()
  });
}

/**
 * Track pagination interaction
 * @param {number} pageNumber - Page number selected
 * @param {Object} options - Additional properties (per_page, total_results, etc.)
 */
export function trackPagination(pageNumber, options = {}) {
  pushEvent({
    'event': 'pagination',
    'page_number': pageNumber,
    'timestamp': new Date().toISOString(),
    ...options
  });
}

/**
 * Track a custom interaction
 * @param {string} eventName - Name of the event
 * @param {Object} eventData - Custom event properties
 */
export function trackCustomEvent(eventName, eventData = {}) {
  pushEvent({
    'event': eventName,
    'timestamp': new Date().toISOString(),
    ...eventData
  });
}

/**
 * Signal to Tag Manager that DOM content has been updated and Element Visibility conditions should be re-evaluated
 * This is crucial for Matomo Tag Manager's Element Visibility triggers to work on page navigation without refresh
 * Tag Manager creates Element Visibility triggers that only evaluate on initial page load—calling this
 * after turbo:load tells Tag Manager to re-check visibility conditions for elements that may have appeared/disappeared
 * @see https://matomo.org/guide/matomo-tag-manager/element-visibility/
 */
export function notifyDOMUpdated() {
  pushEvent({
    'event': 'dom_updated',
    'timestamp': new Date().toISOString()
  });
}

/**
 * Listen for Turbo navigation and track page views automatically
 * This allows Tag Manager to track history changes (page views without full page refresh)
 */
function initTurboTracking() {
  let previousPageUrl = null;

  document.addEventListener('turbo:load', function(event) {
    // Only track if URL actually changed (not the initial page load)
    if (previousPageUrl && previousPageUrl !== window.location.href) {
      trackPageView(window.location.href, document.title);
      // Signal to Tag Manager that DOM has been updated so Element Visibility triggers are re-evaluated
      notifyDOMUpdated();
    }
    previousPageUrl = window.location.href;
  });
}

// Initialize automatic Turbo tracking when module loads
initTurboTracking();
