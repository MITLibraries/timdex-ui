const resultsContainer = document.querySelector('.results-list');

if (resultsContainer) {
  resultsContainer.addEventListener('click', (event) => {
    const link = event.target.closest('a');

    // Discard clicks that aren't on links
    if (!link || !resultsContainer.contains(link)) return;

    const data = new FormData();
    data.append('experiment', 'result_format');
    console.log(data);
    navigator.sendBeacon('/beacon', data);
  });
}
