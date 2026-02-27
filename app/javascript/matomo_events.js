/**
 * Matomo Events Tracking Utility
 * 
 * This module provides a unified interface for tracking events with Matomo,
 * supporting both Matomo Tag Manager (_mtm) and Legacy Matomo (_paq).
 * 
 * Usage:
 *   window.matomoTracker.trackSearch({ keyword: 'biology', filters: ['peer-reviewed'] })
 *   window.matomoTracker.trackTabClick('primo')
 *   window.matomoTracker.trackFilterClick('language', 'English')
 *   window.matomoTracker.trackPagination(2)
 *   window.matomoTracker.trackRecordClick('title-of-record')
 */

const MatomoTracker = (() => {
  /**
   * Detect which Matomo mode is active
   * @returns {string} 'tagmanager' | 'legacy' | 'none'
   */
  const detectMode = () => {
    if (typeof window._mtm !== 'undefined') {
      return 'tagmanager';
    }
    if (typeof window._paq !== 'undefined') {
      return 'legacy';
    }
    return 'none';
  };

  /**
   * Push event to Matomo Tag Manager via _mtm data layer
   * Events pushed to _mtm are processed by Matomo Tag Manager container triggers
   * 
   * @param {string} eventName - Event name (e.g., 'search', 'tab_click')
   * @param {object} eventData - Key-value pairs for event properties
   */
  const pushToTagManager = (eventName, eventData = {}) => {
    if (typeof window._mtm === 'undefined') return;

    const event = {
      event: `matomo_${eventName}`,
      ...eventData,
    };

    window._mtm.push(event);

    // Log for debugging in browser console
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      console.log(`[Matomo Tag Manager] Event pushed:`, event);
    }
  };

  /**
   * Push event to Legacy Matomo via _paq
   * Uses trackEvent() method for custom events
   * 
   * @param {string} category - Event category (e.g., 'search')
   * @param {string} action - Event action (e.g., 'submit')
   * @param {string} name - Event name (e.g., 'biology')
   * @param {number} value - Optional numeric value
   */
  const pushToLegacy = (category, action, name, value) => {
    if (typeof window._paq === 'undefined') return;

    const args = ['trackEvent', category, action, name];
    if (value !== undefined && value !== null) {
      args.push(value);
    }

    window._paq.push(args);

    // Log for debugging in browser console
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      console.log(`[Matomo Legacy] Event pushed:`, { category, action, name, value });
    }
  };

  /**
   * Generic push method that routes to the appropriate Matomo mode
   * For Tag Manager: sends as named event with object data
   * For Legacy: sends as category/action/name tuple
   * 
   * @param {object} config - Configuration object
   *   - eventName: string (e.g., 'search_submit')
   *   - category: string for legacy (e.g., 'Search')
   *   - action: string for legacy (e.g., 'Submit')
   *   - value: string/number for legacy (e.g., 'biology')
   *   - data: object for tag manager (e.g., { keyword: 'biology', filters: [...] })
   */
  const push = (config) => {
    const mode = detectMode();

    if (mode === 'tagmanager') {
      pushToTagManager(config.eventName, config.data);
    } else if (mode === 'legacy') {
      pushToLegacy(config.category, config.action, config.value);
    }
  };

  // Public API
  return {
    /**
     * Track a search submission
     * @param {object} options
     *   - keyword: string (search query)
     *   - filters: array of applied filter strings (optional)
     */
    trackSearch: (options = {}) => {
      push({
        eventName: 'search_submit',
        category: 'Search',
        action: 'Submit',
        value: options.keyword || '',
        data: {
          keyword: options.keyword || '',
          filters: options.filters || [],
          filterCount: (options.filters || []).length,
        },
      });
    },

    /**
     * Track a tab switch event
     * @param {string} tabName - Name of the tab ('primo', 'timdex', 'all')
     */
    trackTabClick: (tabName) => {
      push({
        eventName: 'tab_click',
        category: 'Navigation',
        action: 'Tab Switch',
        value: tabName || '',
        data: {
          tab: tabName || '',
        },
      });
    },

    /**
     * Track a filter interaction
     * @param {string} category - Filter category (e.g., 'language', 'content_type')
     * @param {string} term - Filter term (e.g., 'English')
     * @param {string} action - 'add' or 'remove'
     */
    trackFilterClick: (category, term, action = 'add') => {
      push({
        eventName: 'filter_click',
        category: 'Filters',
        action: `${action}_${category}`,
        value: term || '',
        data: {
          filterCategory: category || '',
          filterTerm: term || '',
          filterAction: action || 'add',
        },
      });
    },

    /**
     * Track pagination interaction
     * @param {number} pageNumber - Page number (or offset)
     * @param {string} direction - 'first' | 'previous' | 'next' | 'direct'
     */
    trackPagination: (pageNumber, direction = 'direct') => {
      push({
        eventName: 'pagination_click',
        category: 'Navigation',
        action: 'Pagination',
        value: String(pageNumber),
        data: {
          page: pageNumber,
          direction: direction,
        },
      });
    },

    /**
     * Track a record (result) click
     * @param {string} recordTitle - Title of the record/result clicked
     * @param {string} recordId - Unique identifier (if available)
     */
    trackRecordClick: (recordTitle, recordId = '') => {
      push({
        eventName: 'record_click',
        category: 'Results',
        action: 'Click',
        value: recordTitle || '',
        data: {
          recordTitle: recordTitle || '',
          recordId: recordId || '',
        },
      });
    },

    /**
     * Track advanced search panel toggle
     * @param {string} panelName - Name of the panel ('advanced', 'geobox', 'geodistance')
     * @param {boolean} isOpen - Whether panel is now open
     */
    trackAdvancedSearchToggle: (panelName, isOpen) => {
      push({
        eventName: 'search_panel_toggle',
        category: 'Search',
        action: `Toggle ${panelName}`,
        value: isOpen ? 'open' : 'closed',
        data: {
          panel: panelName,
          state: isOpen ? 'open' : 'closed',
        },
      });
    },

    /**
     * Track a virtual page view (for SPA navigation in Tag Manager mode)
     * This supplements or replaces trackPageView for Hotwire navigation
     * @param {string} url - Page URL
     * @param {string} title - Page title
     */
    trackPageView: (url, title) => {
      // For Tag Manager, push a virtual pageview event
      pushToTagManager('page_view', {
        pageUrl: url || window.location.href,
        pageTitle: title || document.title,
      });

      // Legacy Matomo handles this via turbo:load listener in _head.html.erb
    },

    mode: detectMode,
  };
})();

// Expose globally for use in inline event handlers and other scripts
window.matomoTracker = MatomoTracker;

export default MatomoTracker;
