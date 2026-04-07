// BACKGROUND
// This file implements helper functions that make it very straigtforward to track Matomo events in code.
// These functions use matomo's _paq.push() API to send events directly to Matomo.
// This does NOT use Tag Manager, but works in core matomo or Tag Manager environments.
//
// CLICK TRACKING
// Add `data-matomo-click="Category, Action, Name"` to any element to track
// clicks as Matomo events. The Name segment is optional. We have a convention 
// of using semicolons inside Name to divide multiple values.
//
// This tracking can be placed directly on an interactive element.
// Tracking also works if placed on a container. The script will look
// for any interactive elements inside the container.
//
// Interactive elemenets are defined as elements: a, button, input, select, textarea
//
// Examples:
//   <a href="/file.pdf" data-matomo-click="Downloads, PDF Click, My Paper">Download</a>
//   <button data-matomo-click="Search, Boolean Toggle">AND/OR</button>
//
// Event delegation on `document` means this works for elements loaded
// asynchronously (Turbo frames, content-loader, etc.) without re-binding.
//
// SEEN TRACKING
// Add `data-matomo-seen="Category, Action, Name"` to any element to fire a
// Matomo event when that element becomes visible in the viewport. The Name
// segment is optional. We have a convention of using semicolons inside Name 
// to divide multiple values. Each element fires at most once per page load.
// Works for elements present on initial page load and for elements injected
// later by Turbo frames or async content loaders.
//
// Examples:
//   <div data-matomo-seen="Impressions, Result Card, Alma">...</div>
//   <a data-matomo-seen="Promotions, Banner Shown">...</a>
//
// DYNAMIC VALUES
// Wrap a helper name in double curly braces anywhere inside a segment to have
// it replaced with the return value of that function at tracking time. Helpers
// must be registered on `window.MatomoHelpers` (see bottom of this file).
// Multiple tokens in one segment are supported.
//
// Convention is to only use these in the "Name" segement to provide more context.
// Avoid using inside Category or Action to improve the hierarchy of Matomo dashboards.
//
// Examples:
//   <h2 data-matomo-seen="Search, Results Found, Tab: {{getActiveTabName}}">...</h2>
//   <a data-matomo-click="Nav, Link Click, Link: {{getElementText}}">...</a>

// ---------------------------------------------------------------------------
// Shared helper
// ---------------------------------------------------------------------------

// Parse a "Category, Action, Name" attribute string and push a trackEvent call
// to the Matomo queue. Name is optional; returns early if fewer than 2 parts.
// `context` is the DOM element that triggered the event; it is forwarded to
// every helper so functions like getElementText can reference it.
function pushMatomoEvent(raw, context) {

  // Split on commas, trim whitespace from each part, drop any empty strings.
  const parts = (raw || "").split(",").map((s) => s.trim()).filter(Boolean);
  // Matomo requires at least a Category and an Action.
  if (parts.length < 2) return;

  // Resolve any {{functionName}} tokens by calling the matching helper.
  // Each token is replaced in-place, so it can appear anywhere in a segment.
  // The context element is passed as the first argument so helpers can
  // inspect the element that triggered the event (e.g. getElementText).
  const helpers = window.MatomoHelpers || {};
  const resolved = parts.map((part) =>
    part.replace(/\{\{(\w+)\}\}/g, (_, fnName) => {
      const fn = helpers[fnName];
      // Call the function if it exists; otherwise leave the token as-is.
      return (typeof fn === "function") ? fn(context) : `{{${fnName}}}`;
    })
  );

  // Destructure into named variables; `name` will be undefined if not provided.
  const [category, action, name] = resolved;

  // Ensure _paq exists even if the Matomo snippet hasn't loaded yet
  // (e.g. in development). Matomo will replay queued calls once it initialises.
  window._paq = window._paq || [];
  const payload = ["trackEvent", category, action];
  if (name) payload.push(name);
  window._paq.push(payload);
}

// ---------------------------------------------------------------------------
// Click tracking
// ---------------------------------------------------------------------------

// Attach a single click listener to the entire document using the capture
// phase (third argument { capture: true }). Capture phase fires top-down
// before any bubble-phase listeners, which guarantees helpers like
// getActiveTabName() read pre-click DOM state before other listeners
// (e.g. loading_spinner.js's swapTabs) synchronously update it.
document.addEventListener("click", (event) => {
  // Walk up the DOM from the clicked element to find the nearest ancestor
  // (or the element itself) that has a data-matomo-click attribute.
  const el = event.target.closest("[data-matomo-click]");
  // If no such element exists in the ancestor chain, ignore this click.
  if (!el) return;

  // Only fire when the click originated from an interactive element (link,
  // button, or form control). This allows data-matomo-click to be placed on
  // a container and track only meaningful interactions within it, ignoring
  // clicks on surrounding text, padding, or decorative children.
  const interactive = event.target.closest("a, button, input, select, textarea");
  if (!interactive) return;

  // Confirm the interactive element is actually inside the tracked container
  // (guards against the unlikely case where closest() finds an ancestor of el).
  if (!el.contains(interactive) && el !== interactive) return;

  // Pass the interactive element as context so helpers like getElementText
  // can read the text of the specific link or button that was clicked.
  pushMatomoEvent(el.dataset.matomoClick, interactive);
}, { capture: true });

// ---------------------------------------------------------------------------
// Seen tracking
// ---------------------------------------------------------------------------

// Track elements already registered with the viewport observer to avoid
// double-registration if the same node is added to the DOM more than once.
const seenRegistered = new WeakSet();

// Fire a Matomo event when an observed element intersects the viewport.
// Unobserve immediately so the event fires at most once per element.
const viewportObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (!entry.isIntersecting) return;
    // Stop watching — we only want to fire once per element.
    viewportObserver.unobserve(entry.target);
    pushMatomoEvent(entry.target.dataset.matomoSeen, entry.target);
  });
});

// Register a single element with the viewport observer if it carries
// data-matomo-seen and hasn't been registered yet.
function registerIfSeen(el) {
  // Only process element nodes (not text nodes, comments, etc.).
  if (el.nodeType !== Node.ELEMENT_NODE) return;
  // Skip if already registered.
  if (seenRegistered.has(el)) return;

  // Register the element itself if it has the attribute.
  if (el.dataset.matomoSeen) {
    seenRegistered.add(el);
    viewportObserver.observe(el);
  }

  // Also register any descendants — content loaders often inject a whole
  // subtree at once, so walking deep ensures every marked element is caught.
  el.querySelectorAll("[data-matomo-seen]").forEach((child) => {
    if (seenRegistered.has(child)) return;
    seenRegistered.add(child);
    viewportObserver.observe(child);
  });
}

// Register all elements already present in the DOM on initial page load.
document.querySelectorAll("[data-matomo-seen]").forEach((el) => {
  seenRegistered.add(el);
  viewportObserver.observe(el);
});

// ---------------------------------------------------------------------------
// Matomo native content tracking
// ---------------------------------------------------------------------------

// Matomo's built-in content tracking (data-track-content / data-content-name /
// data-content-piece) only scans the DOM at page load. For content injected
// asynchronously (e.g. by the content-loader Stimulus controller), we must
// manually notify Matomo by calling trackContentImpressionsWithinNode on the
// newly-added node.
function trackContentImpressionsIfPresent(el) {
  if (el.nodeType !== Node.ELEMENT_NODE) return;
  // Check the element itself or any descendant for data-track-content.
  const hasContent =
    el.hasAttribute("data-track-content") ||
    el.querySelector("[data-track-content]") !== null;
  if (!hasContent) return;

  window._paq = window._paq || [];
  // Ask Matomo to scan the subtree for content impressions.
  window._paq.push(["trackContentImpressionsWithinNode", el]);
}

// Watch for any new nodes added to the DOM after initial load.
// MutationObserver fires synchronously after each DOM mutation, so it catches
// both Turbo frame renders and content-loader replacements immediately.
const observer = new MutationObserver((mutations) => {
  mutations.forEach((mutation) => {
    // Each mutation record lists the nodes that were added in this batch.
    mutation.addedNodes.forEach((node) => {
      registerIfSeen(node);
      trackContentImpressionsIfPresent(node);
    });
  });
});

// Observe the entire document subtree so no async insertion is missed.
observer.observe(document.body, { childList: true, subtree: true });

// Turbo Drive navigation replaces document.body with a brand new element,
// which detaches the MutationObserver from the old body. Re-scan and
// re-attach on every turbo:load so full-page navigations are handled.
// (Turbo frame and content-loader updates are covered by the observer above
// because they mutate within the existing body rather than replacing it.)
document.addEventListener("turbo:load", () => {
  // Register any seen elements that arrived with the navigation.
  document.querySelectorAll("[data-matomo-seen]").forEach((el) => {
    if (seenRegistered.has(el)) return;
    seenRegistered.add(el);
    viewportObserver.observe(el);
  });

  // Re-attach the MutationObserver to the new document.body instance.
  observer.observe(document.body, { childList: true, subtree: true });
});


// ===========================================================================
// HELPER FUNCTIONS
// Custom JS to enhance the payload information we provide to Matomo.
// ===========================================================================

// ---------------------------------------------------------------------------
// Get the name of the active search results tab, if any.
// ---------------------------------------------------------------------------
function getActiveTabName() {
  var tabs = document.querySelector('#tabs');
  if (!tabs) {
    return "None"; // #tabs not found
  }

  var activeAnchor = tabs.querySelector('a.active');
  if (!activeAnchor) {
    return "None"; // no active tab
  }

  return activeAnchor.textContent.trim();
}

// ---------------------------------------------------------------------------
// Get the visible text of the element that triggered the event.
// For click tracking this is the interactive element (link, button, etc.).
// For seen tracking this is the element carrying data-matomo-seen.
// Returns an empty string if no context element is available.
// ---------------------------------------------------------------------------
function getElementText(el) {
  if (!el) return "";
  return el.textContent.trim();
}

// ---------------------------------------------------------------------------
// Get the current results page number from the `page` URL parameter.
// Returns "1" when the parameter is absent (the first page has no page param).
// ---------------------------------------------------------------------------
function getCurrentResultsPage() {
  const params = new URLSearchParams(window.location.search);
  return params.get("page") || "1";
}

// ---------------------------------------------------------------------------
// Register helpers on window.MatomoHelpers so they can be referenced with the
// {{functionName}} syntax in data-matomo-seen and data-matomo-click attributes.
// Add new helpers here as needed.
// ---------------------------------------------------------------------------
window.MatomoHelpers = {
  getActiveTabName,
  getElementText,
  getCurrentResultsPage,
};