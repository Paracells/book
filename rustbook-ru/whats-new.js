// Кнопка «Что нового» в шапке книги.
document.addEventListener('DOMContentLoaded', () => {
  addWhatsNewButton()
})

function addWhatsNewButton () {
  var bar = document.querySelector('#mdbook-menu-bar .right-buttons, #menu-bar .right-buttons')
  if (!bar || bar.querySelector('.whats-new-link')) {
    return
  }

  var link = document.createElement('a')
  link.className = 'whats-new-link'
  link.setAttribute('href', 'appendix-08-whats-new.html')
  link.setAttribute('title', 'Что нового в книге')
  link.textContent = 'Что нового'

  bar.insertBefore(link, bar.firstChild)
}
