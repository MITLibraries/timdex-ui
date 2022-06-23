function disableAdvanced() {
  advanced_field.setAttribute('value', '');
  keyword_field.setAttribute('aria-required', true);
  [...details_panel.getElementsByClassName('field')].forEach(
    field => field.value = ''
  );
  keyword_field.setAttribute('placeholder', 'Enter your search');
  advanced_label.classList = 'closed';
  advanced_label.innerText = 'Show advanced search fields';
};

function enableAdvanced() {
  advanced_field.setAttribute('value', 'true');
  keyword_field.setAttribute('aria-required', false);
  keyword_field.setAttribute('placeholder', 'Keyword anywhere');
  advanced_label.classList = 'open';
  advanced_label.innerText = 'Clear advanced search fields';
};

var advanced_field = document.getElementById('advanced-search-field');
var advanced_label = document.getElementById('advanced-search-label');
var advanced_toggle = document.querySelector('summary');
var details_panel = document.getElementById('advanced-search-panel');
var keyword_field = document.getElementById('basic-search-main');

advanced_toggle.addEventListener('click', event => {
  if (details_panel.attributes.hasOwnProperty('open')) {
    disableAdvanced();
  } else {
    enableAdvanced();
  }
  keyword_field.toggleAttribute('required');
  keyword_field.classList.toggle('required');
});

console.log('search_form.js loaded');
