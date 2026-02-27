// These elements aren't loaded with the initial DOM, they appear later.
function initFilterToggle() {
  var filter_toggle = document.getElementById('filter-toggle');
  var filter_panel = document.getElementById('filter-container');
  var filter_categories = document.getElementsByClassName('filter-category');

  // No need for event listeners if filters aren't present.
  if (!filter_toggle || !filter_panel) {
    return;
  }

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
