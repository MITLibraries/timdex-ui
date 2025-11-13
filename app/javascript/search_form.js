var keywordField = document.getElementById('basic-search-main');
var advancedPanel = document.getElementById('advanced-search-panel');
var geoboxPanel = document.getElementById('geobox-search-panel');
var geodistancePanel = document.getElementById('geodistance-search-panel');
var allPanels = document.getElementsByClassName('form-panel');

function togglePanelState(currentPanel) {
  // Only the geoboxPanel and geodistancePanel inputs need to be required. Advanced search inputs do not.
  if (currentPanel === geoboxPanel || currentPanel === geodistancePanel) {
    toggleRequiredFieldset(currentPanel);
  }

  // These two functions are delayed to ensure that events have propagated first. Otherwise, they will fire before
  // the `open` attribute has toggled on the currentPanel, resulting in unexpected behavior.
  setTimeout(toggleKeywordRequired, 0);
  setTimeout(updateKeywordPlaceholder, 0);

  // Finally, enable or disable the search type of the current panel, based on whether it is open or not.
  toggleSearch(currentPanel);
}

function toggleRequiredFieldset(panel) {
  [...panel.getElementsByClassName('field')].forEach((field) => {
    field.value = '';
    field.classList.toggle('required');
    field.toggleAttribute('required');
  });
}

// Each panel has a hidden input that, when true, enables that type of search.
function toggleSearch(panel) {
  let input = panel.querySelector('.fieldset-toggle');
  if (panel.open) {
    input.setAttribute('value', '');
  } else {
    input.setAttribute('value', 'true');
  }
}

// The keyword field is required only if all panels are closed.
function toggleKeywordRequired() {
  if (Array.from(allPanels).every((panel) => !panel.open)) {
    keywordField.setAttribute('required', '');
    keywordField.classList.add('required');
  } else {
    keywordField.removeAttribute('required');
    keywordField.classList.remove('required');
  }
}

// Placeholder text should be 'Keyword anywhere' if any panels are open, and 'Enter your search' otherwise.
function updateKeywordPlaceholder() {
  if (Array.from(allPanels).some((panel) => panel.open)) {
    keywordField.setAttribute('placeholder', 'Keyword anywhere');
  } else {
    keywordField.setAttribute('placeholder', 'Enter your search');
  }
}

// Add event listeners for all panels in the DOM. For GeoData, this is currently both geospatial panels and the advanced
// panel. In all other TIMDEX UI apps, it's just the advanced panel.
if (Array.from(allPanels).includes(geoboxPanel && geodistancePanel)) {
  document.getElementById('geobox-summary').addEventListener('click', () => {
    togglePanelState(geoboxPanel);
  });

  document.getElementById('geodistance-summary').addEventListener('click', () => {
    togglePanelState(geodistancePanel);
  });

  document.getElementById('advanced-summary').addEventListener('click', () => {
    togglePanelState(advancedPanel);
  });
} else {
  document.getElementById('advanced-summary').addEventListener('click', () => {
    togglePanelState(advancedPanel);
  });
}

console.log('search_form.js loaded');
