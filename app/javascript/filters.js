// These elements aren't loaded with the initial DOM, they appear later.
function initFilterToggle() {
  var filter_toggle = document.getElementById('filter-toggle');
  var filter_panel = document.getElementById('filters');
  filter_toggle.addEventListener('click', event => {
    filter_panel.classList.toggle('hidden-sm');
    filter_toggle.classList.toggle('expanded');

  });
}

initFilterToggle();
