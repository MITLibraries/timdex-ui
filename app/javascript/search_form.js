function disableAdvanced() {
  advanced_field.setAttribute('value', '');
  if (geobox_label.classList.contains('closed') && geodistance_label.classList.contains('closed')) {
    keyword_field.toggleAttribute('required');
    keyword_field.classList.toggle('required');
    keyword_field.setAttribute('aria-required', true);
    keyword_field.setAttribute('placeholder', 'Enter your search');
  }
  [...details_panel.getElementsByClassName('field')].forEach(
    field => field.value = ''
  );
  advanced_label.classList = 'closed';
  advanced_label.innerText = 'Advanced search';
};

function enableAdvanced() {
  advanced_field.setAttribute('value', 'true');
  if (geobox_label.classList.contains('closed') && geodistance_label.classList.contains('closed')) {
    keyword_field.toggleAttribute('required');
    keyword_field.classList.toggle('required');
    keyword_field.setAttribute('aria-required', false);
    keyword_field.setAttribute('placeholder', 'Keyword anywhere');
  }
  advanced_label.classList = 'open';
  advanced_label.innerText = 'Close advanced search';
};

function disableGeobox() {
  if (advanced_label.classList.contains('closed') && geodistance_label.classList.contains('closed')) {
    keyword_field.toggleAttribute('required');
    keyword_field.classList.toggle('required');
    keyword_field.setAttribute('aria-required', true);
    keyword_field.setAttribute('placeholder', 'Enter your search');
  }
  geobox_field.setAttribute('value', '');
  [...geobox_details_panel.getElementsByClassName('field')].forEach(function(field) {
    field.value = '';
    field.classList.toggle('required');
    field.toggleAttribute('required');
    field.setAttribute('aria-required', false);
  });
  geobox_label.classList = 'closed';
  geobox_label.innerText = 'Geospatial bounding box search';
};

function enableGeobox() {
  if (advanced_label.classList.contains('closed') && geodistance_label.classList.contains('closed')) {
    keyword_field.toggleAttribute('required');
    keyword_field.classList.toggle('required');
    keyword_field.setAttribute('aria-required', false);
    keyword_field.setAttribute('placeholder', 'Keyword anywhere');
  }
  geobox_field.setAttribute('value', 'true');
  [...geobox_details_panel.getElementsByClassName('field')].forEach(function(field) {
    field.value = '';
    field.classList.toggle('required');
    field.toggleAttribute('required');
    field.setAttribute('aria-required', true);
  });
  geobox_label.classList = 'open';
  geobox_label.innerText = 'Close bounding box search';
};

function disableGeodistance() {
  if (advanced_label.classList.contains('closed') && geobox_label.classList.contains('closed')) {
    keyword_field.toggleAttribute('required');
    keyword_field.classList.toggle('required');
    keyword_field.setAttribute('aria-required', true);
    keyword_field.setAttribute('placeholder', 'Enter your search');
  }
  geodistance_field.setAttribute('value', '');
  [...geodistance_details_panel.getElementsByClassName('field')].forEach(function(field) {
    field.value = '';
    field.classList.toggle('required');
    field.toggleAttribute('required');
    field.setAttribute('aria-required', false);
  });
  geodistance_label.classList = 'closed';
  geodistance_label.innerText = 'Geospatial distance search';
};

function enableGeodistance() {
  if (advanced_label.classList.contains('closed') && geobox_label.classList.contains('closed')) {
    keyword_field.toggleAttribute('required');
    keyword_field.classList.toggle('required');
    keyword_field.setAttribute('aria-required', false);
    keyword_field.setAttribute('placeholder', 'Keyword anywhere');
  }
  geodistance_field.setAttribute('value', 'true');
  [...geodistance_details_panel.getElementsByClassName('field')].forEach(function(field) {
    field.value = '';
    field.classList.toggle('required');
    field.toggleAttribute('required');
    field.setAttribute('aria-required', true);
  });
  geodistance_label.classList = 'open';
  geodistance_label.innerText = 'Close distance search';
};


var advanced_field = document.getElementById('advanced-search-field');
var advanced_label = document.getElementById('advanced-search-label');
var advanced_toggle = document.getElementById('advanced-summary');
var details_panel = document.getElementById('advanced-search-panel');
var keyword_field = document.getElementById('basic-search-main');
var geobox_field = document.getElementById('geobox-search-field');
var geobox_label = document.getElementById('geobox-search-label');
var geobox_toggle = document.getElementById('geobox-summary');
var geobox_details_panel = document.getElementById('geobox-search-panel');
var geodistance_field = document.getElementById('geodistance-search-field');
var geodistance_label = document.getElementById('geodistance-search-label');
var geodistance_toggle = document.getElementById('geodistance-summary');
var geodistance_details_panel = document.getElementById('geodistance-search-panel');

geobox_toggle.addEventListener('click', event => {
  if (geobox_details_panel.attributes.hasOwnProperty('open')) {
    disableGeobox();
  } else {
    enableGeobox();
  }
});

geodistance_toggle.addEventListener('click', event => {
  if (geodistance_details_panel.attributes.hasOwnProperty('open')) {
    disableGeodistance();
  } else {
    enableGeodistance();
  }
});

advanced_toggle.addEventListener('click', event => {
  if (details_panel.attributes.hasOwnProperty('open')) {
    disableAdvanced();
  } else {
    enableAdvanced();
  }
});

console.log('search_form.js loaded');
