// These elements aren't loaded with the initial DOM, they appear later.
function initFilterToggle() {
  var filter_toggle = document.getElementById('filter-toggle');
  var filter_panel = document.getElementById('filter-container');
  var filter_categories = document.getElementsByClassName('filter-category');
  filter_toggle.addEventListener('click', event => {
    filter_panel.classList.toggle('hidden-md');
    filter_toggle.classList.toggle('expanded');
  });
  [...filter_categories].forEach(element => {
    element.addEventListener('click', event => {
      element.getElementsByClassName('filter-label')[0].classList.toggle('expanded');
    });
  });
}

initFilterToggle();

// Track filter clicks
document.addEventListener('click', function(event) {
  const clickedElement = event.target;
  
  // Check if the click is on a filter term link (nested inside .category-terms)
  const filterLink = clickedElement.closest('.category-terms .term a');
  if (filterLink) {
    // Find the parent filter-category to get the filter name
    const filterCategory = filterLink.closest('.filter-category');
    if (filterCategory) {
      // Get the filter name from the summary
      const filterLabel = filterCategory.querySelector('.filter-label');
      if (filterLabel && window.matomoTracker) {
        // Extract the filter term from the link text (it's in a .name span)
        const termSpan = filterLink.querySelector('.name');
        const filterTerm = termSpan ? termSpan.textContent.trim() : 'unknown';
        
        // Extract the filter category from the label text
        const filterCategoryName = filterLabel.textContent.trim();
        
        // Determine if this is adding or removing a filter
        const isApplied = filterLink.classList.contains('applied');
        const action = isApplied ? 'remove' : 'add';
        
        window.matomoTracker.trackFilterClick(filterCategoryName, filterTerm, action);
      }
    }
  }
}, true); // Use capture phase to catch events before they propagate
