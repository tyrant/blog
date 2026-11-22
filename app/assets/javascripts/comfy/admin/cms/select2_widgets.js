// Enhances the admin's Select2 widgets: the blog post form's tag multi-select
// and the quotation form's Substack user picker. Uses its own bundled jQuery
// (Comfy's legacy widgets run on the global one); the two coexist fine since
// Select2 only ever touches the selects below.
import $ from 'jquery'
import select2 from 'select2'

// select2's CommonJS entry is a lazy factory — it only attaches $.fn.select2
// once called with (window, jQuery); a bare `import 'select2'` is a no-op.
// Call it only here: a second call would register the plugin twice.
select2(window, $)

const WIDGETS = {
  '.js-tags-select': {
    width: '100%',
    placeholder: 'Add tags…',
    closeOnSelect: false
  },
  // Single select over every Substack user; Select2's search box filters the
  // options client-side. The blank option + allowClear lets the author be unset.
  // Its placeholder comes from the <select>'s data-placeholder.
  '.js-substack-user-select': {
    width: '100%',
    allowClear: true
  }
}

function initSelect2Widgets() {
  Object.entries(WIDGETS).forEach(([selector, options]) => {
    $(selector).each(function () {
      const $select = $(this)
      if ($select.hasClass('select2-hidden-accessible')) return // already initialised
      $select.select2(options)
    })
  })
}

$(initSelect2Widgets)
document.addEventListener('turbolinks:load', initSelect2Widgets)
document.addEventListener('turbo:load', initSelect2Widgets)
