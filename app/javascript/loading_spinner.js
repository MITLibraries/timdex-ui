import { trackPagination } from 'matomo_events'

// Update the tab UI to reflect the newly-requested state. This function is called
// by a click event handler in the tab UI. It follows a two-step process:
function swapTabs(new_target) {
  // 1. Reset all tabs to base condition
  document.querySelectorAll('.tab-link').forEach((tab) => {
    tab.classList.remove('active');
    tab.removeAttribute('aria-current');
  });
  // 2. Add "active" class and aria-current attribute to the newly-active tab link
  const currentTabLink = document.querySelector(`.tab-link[href*="tab=${new_target}"]`);
  if (currentTabLink) {
    currentTabLink.classList.add('active');
    currentTabLink.setAttribute('aria-current', 'page');
  }
}

// Loading spinner behavior for pagination (Turbo Frame updates)
document.addEventListener('turbo:frame-render', function(event) {
  if (window.pendingFocusAction === 'pagination') {
    // Focus on first result for pagination
    const firstResult = document.querySelector('.results-list .result h3 a, .results-list .result .record-title a');
    if (firstResult) {
      firstResult.focus();
    }

    // Remove the spinner now that things are ready
    document.getElementById('search-results').classList.remove('spinner');

    // Clear the pending action
    window.pendingFocusAction = null;
  };

  if (window.pendingFocusAction === 'tab') {
    // console.log("Tab change detected - focusing on first result");

    const urlParams = new URLSearchParams(window.location.search);
    const queryParam = urlParams.get('tab');
    const searchInput = document.querySelector('input[name="tab"]');
    
    // update hidden form element to ensure correct tab is used for subsequent searches
    if (searchInput && queryParam != null) {
      searchInput.value = queryParam;
      // console.log(`Updated tab input value to: ${queryParam}`);
    }

    // Remove the spinner now that things are ready
    document.getElementById('search-results').classList.remove('spinner');

    // Clear the pending action
    window.pendingFocusAction = null;
  };
});

document.addEventListener('click', function(event) {
  const clickedElement = event.target;

  // Handle pagination clicks
  if (clickedElement.matches('.first a, .previous a, .next a')) {
    // Track pagination
    const urlParams = new URLSearchParams(clickedElement.href);
    const pageParam = urlParams.get('page');
    if (pageParam) {
      trackPagination(parseInt(pageParam));
    }

    // Throw the spinner on the search results immediately
    document.getElementById('search-results').classList.add('spinner');

    // Position the window at the top of the results
    window.scrollTo({ top: 0, behavior: 'smooth' });

    window.pendingFocusAction = 'pagination';
  }

  // Handle tab clicks
  if (clickedElement.closest('.tab-navigation')) {

    // If the element is NOT a link, don't show the spinner
    if (clickedElement.nodeName !== "A") { return; }

    const clickedParams = new URLSearchParams(clickedElement.search);
    const newTab = clickedParams.get('tab');

    // Throw the spinner on the search results immediately
    document.getElementById('search-results').classList.add('spinner');

    // Position the window at the top of the results
    window.scrollTo({ top: 0, behavior: 'smooth' });

    swapTabs(newTab);

    window.pendingFocusAction = 'tab';
  }
});

// On Turbo Frame render, update the search input value to match the current URL parameter
// This ensures that after using the back button the search input reflects the correct query
document.addEventListener('turbo:load', function(event) {
  // update form element name 'q' to use current url paramater `q`
  // console.log(`turbo:frame-render event detected for frame: ${event.target.id}`);
  const urlParams = new URLSearchParams(window.location.search);
  const queryParam = urlParams.get('q');
  const searchInput = document.querySelector('input[name="q"]');
  if (searchInput && queryParam != null) {
    searchInput.value = queryParam;
    // console.log(`Updated search input value to: ${queryParam}`);
  }
});


