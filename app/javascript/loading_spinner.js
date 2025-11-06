// Loading spinner behavior for pagination (Turbo Frame updates)
document.addEventListener('turbo:frame-render', function(event) {
  if (window.pendingFocusAction === 'pagination') {
    // Focus on first result for pagination
    const firstResult = document.querySelector('.results-list .result h3 a, .results-list .result .record-title a');
    if (firstResult) {
      firstResult.focus();
    }
    // Clear the pending action
    window.pendingFocusAction = null;
  }
});

document.addEventListener('click', function(event) {
  const clickedElement = event.target;

  // Handle pagination clicks
  if (clickedElement.closest('.pagination-container') || 
      clickedElement.matches('.first a, .previous a, .next a')) {
    window.scrollTo({ top: 0, behavior: 'smooth' });
    window.pendingFocusAction = 'pagination';
  }
});