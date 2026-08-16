// Drag-to-reorder for the Substack Quotations admin list. Persists the new order
// (quotation ids, top-to-bottom) to PUT /admin/quotations/reorder and renumbers
// the visible order badges. No-op on pages without the list.
window.CMS.quotationsSort = {
  init: function() {
    this.list = document.getElementById('quotation-sortable');
    if (!this.list || typeof Sortable === 'undefined') return;

    var self = this;
    var list = this.list;
    this.sortable = Sortable.create(list, {
      handle: '.dragger',
      draggable: 'li',
      animation: 150,
      onStart: function() { list.classList.add('dragging'); },
      onEnd: function() { list.classList.remove('dragging'); self.persist(); }
    });
  },

  dispose: function() {
    if (this.sortable) {
      this.sortable.destroy();
      this.sortable = null;
    }
  },

  persist: function() {
    this.renumber();
    var order = Array.prototype.map.call(this.list.children, function(li) {
      return li.getAttribute('data-id');
    });
    var csrf = document.querySelector('meta[name="csrf-token"]').content;
    fetch(this.list.getAttribute('data-reorder-url'), {
      method: 'PUT',
      headers: { 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ order: order })
    });
  },

  renumber: function() {
    var n = 1;
    this.list.querySelectorAll('.order-number').forEach(function(el) {
      el.textContent = n++;
    });
  }
};
