# Matomo Tag Manager Event Tracking Implementation

## Overview

This document describes the Matomo Tag Manager event tracking implementation for timdex-ui. The solution enables Matomo to track user interactions and page views when the page isn't fully refreshed—including history changes, tab selections, search submissions, filter interactions, and pagination.

## Why This Was Needed

When using Matomo **Tag Manager mode** (configured via `MATOMO_CONTAINER_URL`), the tag manager doesn't automatically track custom events. Without explicit event pushes to the `_mtm` queue, only the initial page load is tracked. When users navigate via Turbo Rails SPA features (without full page refresh), Tag Manager never sees those interactions.

## Architecture

### Module: `app/javascript/matomo_events.js`

The core event dispatcher module that:
- Ensures `window._mtm` queue exists
- Exports helper functions to push events to Tag Manager
- Automatically listens to `turbo:load` events (SPA navigation) and tracks page views
- Provides specialized tracking functions for common interactions

**Key Exports:**
- `trackPageView(pageUrl, pageTitle)` - Track page views on history changes
- `trackSearch(query, options)` - Track search submissions
- `trackFilterChange(filterName, filterValue, action)` - Track filter interactions
- `trackTabChange(tabName)` - Track source tab selections
- `trackPagination(pageNumber, options)` - Track pagination
- `trackCustomEvent(eventName, eventData)` - Generic event tracker

### Integration Points

#### 1. **Initial Page View** – `app/views/layouts/_head.html.erb`
```javascript
// Added to Tag Manager initialization
_mtm.push({
  'event': 'page_view',
  'page_url': window.location.href,
  'page_path': window.location.pathname + window.location.search,
  'page_title': document.title,
  'timestamp': new Date().toISOString()
});
```

#### 2. **SPA Navigation** – `app/javascript/matomo_events.js`
Automatically tracks page views when `turbo:load` fires (detects URL changes without full page refresh).

#### 3. **Tab Selection** – `app/javascript/source_tabs.js`
```javascript
trackTabChange(tabName) // When user clicks primo/timdex/all tabs
```

#### 4. **Filter Interactions** – `app/javascript/filters.js`
```javascript
trackFilterChange(filterName, filterValue, action) // When filter categories expand/collapse
```

#### 5. **Search Submissions** – `app/javascript/search_form.js`
```javascript
trackSearch(query, options) // When user submits search
trackCustomEvent('search_panel_toggled', { panel_type: 'advanced' }) // Panel toggles
```

#### 6. **Pagination** – `app/javascript/loading_spinner.js`
```javascript
trackPagination(pageNumber) // When user clicks pagination links
```

### Event Data Structure

All events pushed to `_mtm` follow a consistent structure:
```javascript
{
  'event': 'event_name',        // Required: identifies the event type
  'timestamp': ISO8601String,   // When the event occurred
  // ... additional custom properties
}
```

**Event Types Generated:**
- `page_view` - Page navigation without refresh
- `search_submitted` - User submitted a search
- `filter_interaction` - User changed filters
- `tab_selected` - User selected a source tab
- `pagination` - User navigated to a different page
- `search_panel_toggled` - User opened/closed advanced/geospatial search panels
- Custom events via `trackCustomEvent()`

## Configuration in Matomo Tag Manager

To capture and process these events in your Matomo Tag Manager:

### Step 1: Create Data Layer Variable (Optional)
In Tag Manager UI, create variables to extract event properties:
- Variable Type: Data Layer Variable
- Data Layer Variable Name: `event` (captures the event type)

### Step 2: Create Triggers
Create triggers that listen for custom events:

1. **Page View Trigger**
   - Trigger Type: Custom Event
   - Event Name: `page_view` (exactly match the event name pushed to `_mtm`)
   - Trigger fires on: All Custom Events with event type = page_view

2. **Search Trigger**
   - Trigger Type: Custom Event
   - Event Name: `search_submitted`

3. **Filter Trigger**
   - Trigger Type: Custom Event
   - Event Name: `filter_interaction`

4. **Tab Trigger**
   - Trigger Type: Custom Event
   - Event Name: `tab_selected`

5. **Pagination Trigger**
   - Trigger Type: Custom Event
   - Event Name: `pagination`

### Step 3: Create Tags
Create tags that fire on these triggers. Examples:

1. **Matomo Pageview Tag**
   - Trigger: Page View Trigger
   - Tag Type: Matomo Analytics
   - Action: Track Page View
   - Page Title: `{{page_title}}`
   - Page URL: `{{page_url}}`

2. **Matomo Event Tag** (for site search, filters, tabs, etc.)
   - Trigger: (specific event trigger)
   - Tag Type: Matomo Analytics
   - Action: Track Event
   - Category: `custom_user_interaction` (or appropriate category)
   - Action: `{{event}}`
   - Label: (extract from event data if needed)

## How It Works: User Flow

1. **User loads page** → Initial page view tracked via `_head.html.erb`
2. **User navigates to search results** → `turbo:load` fires → `matomo_events.js` automatically pushes page_view to `_mtm`
3. **User selects a tab (Primo/Timdex)** → `source_tabs.js` calls `trackTabChange()` → Event pushed to `_mtm` → Tag Manager trigger captures it
4. **User applies filters** → `filters.js` calls `trackFilterChange()` → Event pushed to `_mtm` → Tag Manager trigger captures it
5. **User submits search** → `search_form.js` calls `trackSearch()` → Event pushed to `_mtm` → Tag Manager trigger captures it
6. **User clicks pagination** → `loading_spinner.js` calls `trackPagination()` → Event pushed to `_mtm` → Tag Manager trigger captures it

Tag Manager processes these events according to your configured triggers/tags and sends them to your Matomo analytics backend.

## Testing

To verify tracking is working:

1. **Check in Matomo Real-time View:**
   - Navigate through the app without page refresh
   - You should see events appearing in real-time in your Matomo instance

2. **Use browser console:**
   ```javascript
   // Check if _mtm queue has events
   console.log(window._mtm);
   ```
   You should see entries like:
   ```javascript
   [{event: 'page_view', page_url: '...', timestamp: '...'}, ...]
   ```

3. **Use Tag Manager Debug Mode:**
   - See Matomo Tag Manager's debug console to verify triggers are firing and tags are executing

## Environment Variables

Make sure these are configured for Tag Manager to work:

- `MATOMO_CONTAINER_URL` - URL to your Matomo Tag Manager container script (e.g., `https://yourdomain.matomo.cloud/path/to/container.js`)

Do NOT set `MATOMO_URL` and `MATOMO_SITE_ID` if using Tag Manager mode (they enable legacy mode instead).

## Files Modified

- `app/javascript/matomo_events.js` (created)
- `app/javascript/application.js` (added import)
- `app/views/layouts/_head.html.erb` (added initial page_view event)
- `app/javascript/source_tabs.js` (added tab tracking)
- `app/javascript/filters.js` (added filter tracking)
- `app/javascript/search_form.js` (added search & panel tracking)
- `app/javascript/loading_spinner.js` (added pagination tracking)
- `config/importmap.rb` (added matomo_events module)

## Troubleshooting

### Events not appearing in Matomo
1. Verify `MATOMO_CONTAINER_URL` is set correctly and the container script loads successfully (check browser Network tab)
2. Confirm Tag Manager triggers match the event names being pushed (exactly case-sensitive)
3. Check browser console for any JavaScript errors
4. Use Tag Manager's debug mode to see which events are being captured

### Events only on initial page load
This usually means `turbo:load` tracking is working but other interactions aren't. Check:
1. That the JavaScript modifications to `source_tabs.js`, `filters.js`, etc. are correct
2. Browser console for any import/module errors
3. That the event functions are being called when interactions happen

### Performance or double-tracking
- Events are pushed asynchronously to `_mtm` without blocking page interactions
- No duplicate pushes should occur; each interaction has one tracking point
- If seeing duplicates, check Tag Manager trigger conditions to ensure they don't match multiple times

## Future Enhancements

Possible additions to track more interactions:
- Link clicks to external resources
- Facet/filter value selections (not just category expansions)
- Full record view interactions
- OpenAlex/LibKey fulfillment link clicks
- Error/failed search tracking
