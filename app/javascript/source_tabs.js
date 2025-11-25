const container = document.querySelector('#tabs')
const primary = container.querySelector('.primary')
const primaryItems = container.querySelectorAll('.primary > li:not(.-more)')
container.classList.add('has-js')

// insert "more" button and duplicate the list

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
moreBtn.addEventListener('click', (e) => {
  e.preventDefault()
  container.classList.toggle('--show-secondary')
  moreBtn.setAttribute('aria-expanded', container.classList.contains('--show-secondary'))
})

// adapt tabs

const doAdapt = () => {
  // reveal all items for the calculation
  allItems.forEach((item) => {
    item.classList.remove('--hidden')
  })

  // hide items that won't fit in the Primary
  let stopWidth = moreBtn.offsetWidth
  let hiddenItems = []
  const primaryWidth = primary.offsetWidth
  primaryItems.forEach((item, i) => {
    if(primaryWidth >= stopWidth + item.offsetWidth) {
      stopWidth += item.offsetWidth
    } else {
      item.classList.add('--hidden')
      hiddenItems.push(i)
    }
  })
  
  // toggle the visibility of More button and items in Secondary
  if(!hiddenItems.length) {
    moreLi.classList.add('--hidden')
    container.classList.remove('--show-secondary')
    moreBtn.setAttribute('aria-expanded', false)
  }
  else {  
    secondaryItems.forEach((item, i) => {
      if(!hiddenItems.includes(i)) {
        item.classList.add('--hidden')
      }
    })
  }
}

doAdapt() // adapt immediately on load
window.addEventListener('resize', doAdapt) // adapt on window resize

// hide Secondary on the outside click
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