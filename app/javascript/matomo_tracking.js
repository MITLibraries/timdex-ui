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
  const el = event.target.closest("[data-matomo-click]");
  if (!el) return;

  const raw = el.dataset.matomoClick || "";
  const parts = raw.split(",").map((s) => s.trim()).filter(Boolean);
  if (parts.length < 2) return;

  const [category, action, name] = parts;

  window._paq = window._paq || [];
  const payload = ["trackEvent", category, action];
  if (name) payload.push(name);
  window._paq.push(payload);
});
