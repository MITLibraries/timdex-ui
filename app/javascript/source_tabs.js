// ===========================================================================
// RESPONSIVE TAB BAR LOGIC WITH GRACEFUL DEGRADATION
// Source: https://css-tricks.com/container-adapting-tabs-with-more-button/
// ===========================================================================

// Initialize tab bar functionality
const initTabs = () => {
  // Store references to relevant selectors
  const container = document.querySelector('#tabs')
  if (!container) return // Exit if tabs element doesn't exist
  if (container.classList.contains('has-js')) return // Already initialized

  const primary = container.querySelector('.primary')
  const primaryItems = container.querySelectorAll('.primary > li:not(.-more)')

  // Add a class to turn off graceful degradation style
  container.classList.add('has-js')

  // insert "more" button and duplicate the original tab bar items
  primary.insertAdjacentHTML('beforeend', `
    <li class="-more">
      <button type="button" aria-haspopup="true" aria-expanded="false" aria-controls="more-options">
        More <i class="fa-light fa-chevron-down"></i>
      </button>
      <ul class="-secondary" id="more-options" aria-label="More options">
        ${primary.innerHTML}
      </ul>
    </li>
  `)
  const secondary = container.querySelector('.-secondary')
  const secondaryItems = secondary.querySelectorAll('li')
  const allItems = container.querySelectorAll('li')
  const moreLi = primary.querySelector('.-more')
  const moreBtn = moreLi.querySelector('button')

  // Store original DOM order by index for each li
  Array.from(primary.querySelectorAll('li:not(.-more)')).forEach((li, index) => {
    li.dataset.originalIndex = index
  })
  Array.from(secondary.querySelectorAll('li:not(.-more)')).forEach((li, index) => {
    li.dataset.originalIndex = index
  })

  // When the more button is clicked, toggle classes to indicate the secondary menu is open
  moreBtn.addEventListener('click', (e) => {
    e.preventDefault()
    container.classList.toggle('--show-secondary')
    moreBtn.setAttribute('aria-expanded', container.classList.contains('--show-secondary'))
  })

  // Maximum number of tabs to show in the primary tab bar at once
  const MAX_TABS = 10

  // adapt tabs
  const doAdapt = () => {

    // reveal all items for the calculation
    allItems.forEach((item) => {
      item.classList.remove('--hidden')
    })

    // Get primary items in current DOM order (re-query each time, direct children only)
    const currentPrimaryItems = Array.from(primary.querySelectorAll(':scope > li:not(.-more)'))

    // hide items that won't fit in the Primary tab bar, or exceed MAX_TABS
    // once a tab is hidden, all subsequent tabs are also hidden to preserve order
    let stopWidth = moreBtn.offsetWidth
    let hiddenItems = []
    let shouldHide = false
    const primaryWidth = primary.offsetWidth
    currentPrimaryItems.forEach((item, i) => {
      if(!shouldHide && i < MAX_TABS && primaryWidth >= stopWidth + item.offsetWidth) {
        stopWidth += item.offsetWidth
      } else {
        shouldHide = true
        item.classList.add('--hidden')
        hiddenItems.push(i)
      }
    })
    
    // toggle the visibility of More button and items in Secondary menu
    if(!hiddenItems.length) {
      moreLi.classList.add('--hidden')
      container.classList.remove('--show-secondary')
      moreBtn.setAttribute('aria-expanded', false)
    }
    else {  
      // Re-query secondary items in current DOM order (direct children only)
      const currentSecondaryItems = Array.from(secondary.querySelectorAll(':scope > li:not(.-more)'))
      currentSecondaryItems.forEach((item, i) => {
        if(!hiddenItems.includes(i)) {
          item.classList.add('--hidden')
        }
      })
    }

    // Handle active hidden tab - move it to position 2 (right after "All")
    const activeLink = primary.querySelector('a.active')
    if (activeLink) {
      const activeLi = activeLink.parentElement

      if (activeLi.classList.contains('--hidden')) {
        const activeIndex = currentPrimaryItems.indexOf(activeLi)

        // If active tab is not at position 0 (All) or position 1, move it to position 1
        if (activeIndex > 1) {
          const liAtPos1 = currentPrimaryItems[1]
          
          // Swap in primary by moving active before position 1
          primary.insertBefore(activeLi, liAtPos1)

          // Find matching items in secondary by original index
          const activeOriginalIndex = parseInt(activeLi.dataset.originalIndex)
          const pos1OriginalIndex = parseInt(liAtPos1.dataset.originalIndex)

          const currentSecondaryItems = Array.from(secondary.querySelectorAll(':scope > li:not(.-more)'))
          const secondaryActive = currentSecondaryItems.find(li =>
            parseInt(li.dataset.originalIndex) === activeOriginalIndex
          )
          const secondaryPos1 = currentSecondaryItems.find(li =>
            parseInt(li.dataset.originalIndex) === pos1OriginalIndex
          )

          // Swap in secondary
          if (secondaryActive && secondaryPos1) {
            secondary.insertBefore(secondaryActive, secondaryPos1)
          }

          // Recalculate visibility after swap
          const updatedPrimaryItems = Array.from(primary.querySelectorAll(':scope > li:not(.-more)'))
          const updatedSecondaryItems = Array.from(secondary.querySelectorAll(':scope > li:not(.-more)'))

          // Clear hidden from all items before recalculating
          updatedPrimaryItems.forEach(item => item.classList.remove('--hidden'))
          updatedSecondaryItems.forEach(item => item.classList.remove('--hidden'))
          moreLi.classList.remove('--hidden')

          // Recalculate which items fit
          let newStopWidth = moreBtn.offsetWidth
          let newHiddenItems = []
          let newShouldHide = false

          updatedPrimaryItems.forEach((item, i) => {
            if (!newShouldHide && i < MAX_TABS && primaryWidth >= newStopWidth + item.offsetWidth) {
              newStopWidth += item.offsetWidth
            } else {
              newShouldHide = true
              item.classList.add('--hidden')
              newHiddenItems.push(i)
            }
          })

          // Update secondary visibility
          if (!newHiddenItems.length) {
            moreLi.classList.add('--hidden')
            container.classList.remove('--show-secondary')
            moreBtn.setAttribute('aria-expanded', false)
          } else {
            moreLi.classList.remove('--hidden')
            updatedSecondaryItems.forEach((item, i) => {
              if (!newHiddenItems.includes(i)) {
                item.classList.add('--hidden')
              }
            })
          }
        }
      }
    }
  }

  // Adapt the tabs to fit the viewport
  doAdapt() // immediately on load
  window.addEventListener('resize', doAdapt) // on window resize

  // hide Secondary menu on the outside click
  document.addEventListener('click', (e) => {
    let el = e.target
    while(el) {
      if(el === moreBtn) {
        return;
      }
      el = el.parentNode
    }
    container.classList.remove('--show-secondary')
    moreBtn.setAttribute('aria-expanded', false)
  })
}

// Initialize on page load and after Turbo navigates
// turbo:load fires on both initial page load and subsequent Turbo navigations
document.addEventListener('turbo:load', initTabs)
