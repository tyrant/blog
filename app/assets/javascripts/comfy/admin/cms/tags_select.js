// Enhances the blog post form's tag multi-select with Select2. Uses its own
// bundled jQuery (Comfy's legacy widgets run on the global one); the two
// coexist fine since Select2 only ever touches .js-tags-select.
import $ from 'jquery'
import select2 from 'select2'

// select2's CommonJS entry is a lazy factory — it only attaches $.fn.select2
// once called with (window, jQuery); a bare `import 'select2'` is a no-op.
select2(window, $)

const SELECTOR = '.js-tags-select'

function initTagsSelect() {
  $(SELECTOR).each(function () {
    const $select = $(this)
    if ($select.hasClass('select2-hidden-accessible')) return // already initialised
    $select.select2({
      width: '100%',
      placeholder: 'Add tags…',
      closeOnSelect: false
    })
  })
}

$(initTagsSelect)
document.addEventListener('turbolinks:load', initTagsSelect)
document.addEventListener('turbo:load', initTagsSelect)
