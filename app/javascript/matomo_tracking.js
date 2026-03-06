// Matomo click event tracking via data attributes.
//
// Add `data-matomo-click="Category, Action, Name"` to any element to track
// clicks as Matomo events. The Name segment is optional.
//
// Examples:
//   <a href="/file.pdf" data-matomo-click="Downloads, PDF Click, My Paper">Download</a>
//   <button data-matomo-click="Search, Boolean Toggle">AND/OR</button>
//
// Event delegation on `document` means this works for elements loaded
// asynchronously (Turbo frames, content-loader, etc.) without re-binding.

document.addEventListener("click", (event) => {
  
  // Find the closest ancestor (or self) with the data-matomo-click attribute.
  const el = event.target.closest("[data-matomo-click]");
  if (!el) return;

  // Read the attribute value and break it apart into segments. Trim whitespace and ignore empty segments.
  const raw = el.dataset.matomoClick || "";
  const parts = raw.split(",").map((s) => s.trim()).filter(Boolean);

  // Matomo requires at least a Category and an Action — bail out if we don't have both.
  if (parts.length < 2) return;

  // Destructure into named variables; `name` will be undefined if not provided.
  const [category, action, name] = parts;

  // Build the payload for trackEvent and push to Matomo.
  window._paq = window._paq || [];
  const payload = ["trackEvent", category, action];
  if (name) payload.push(name);
  window._paq.push(payload);
  
});
