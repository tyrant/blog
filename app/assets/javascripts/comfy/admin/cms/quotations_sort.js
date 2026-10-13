// Drag-to-reorder for the paginated Substack Quotations admin list. Each drop
// PUTs a single move — { id, to }, `to` being the quotation's new 0-based index in
// the whole order — to /admin/quotations/reorder. Dropping on the "Previous page" /
// "Next page" zones moves it to the bottom of the previous page / top of the next,
// then reloads so the page shows its reshuffled neighbours. No-op without the list.
//
// The zones aren't Sortable lists: dropping the card into one would pull it out of
// the list, shifting the zone away from the cursor so Sortable snaps it back. They
// only track whether a drag is over them, and onEnd sends their move instead.
window.CMS.quotationsSort = {
  init: function() {
    this.list = document.getElementById('quotation-sortable');
    if (!this.list || typeof Sortable === 'undefined') return;

    var self = this;
    var list = this.list;
    this.zones = Array.prototype.slice.call(document.querySelectorAll('.quotation-drop-zone'));
    this.hoverZone = null;
    this.zoneListeners = [];
    this.zones.forEach(function(zone) {
      self.listen(zone, 'dragover', function(evt) {
        evt.preventDefault();
        self.setHoverZone(zone);
      });
      // Accepting dragover makes the zone a drop target; stop the browser opening the dragged text.
      self.listen(zone, 'drop', function(evt) { evt.preventDefault(); });
      self.listen(zone, 'dragleave', function(evt) {
        if (!zone.contains(evt.relatedTarget)) self.setHoverZone(null);
      });
    });

    this.sortable = Sortable.create(list, {
      handle: '.dragger',
      draggable: 'li',
      animation: 150,
      onStart: function() {
        list.classList.add('dragging');
        document.body.classList.add('quotation-dragging');
      },
      onEnd: function(evt) {
        var zone = self.hoverZone;
        self.setHoverZone(null);
        list.classList.remove('dragging');
        document.body.classList.remove('quotation-dragging');
        if (zone) {
          self.move(evt.item.getAttribute('data-id'), parseInt(zone.getAttribute('data-drop-to'), 10), true);
        } else if (evt.oldIndex !== evt.newIndex) {
          self.renumber();
          self.move(evt.item.getAttribute('data-id'), self.offset() + evt.newIndex, false);
        }
      }
    });
  },

  dispose: function() {
    if (this.sortable) {
      this.sortable.destroy();
      this.sortable = null;
    }
    if (this.zoneListeners) {
      this.zoneListeners.forEach(function(l) { l[0].removeEventListener(l[1], l[2]); });
      this.zoneListeners = null;
    }
  },

  listen: function(element, type, handler) {
    element.addEventListener(type, handler);
    this.zoneListeners.push([element, type, handler]);
  },

  setHoverZone: function(zone) {
    if (this.hoverZone) this.hoverZone.classList.remove('drop-hover');
    this.hoverZone = zone;
    if (zone) zone.classList.add('drop-hover');
  },

  offset: function() {
    return parseInt(this.list.getAttribute('data-offset'), 10);
  },

  move: function(id, to, reload) {
    var csrf = document.querySelector('meta[name="csrf-token"]').content;
    fetch(this.list.getAttribute('data-reorder-url'), {
      method: 'PUT',
      headers: { 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ id: id, to: to })
    }).then(function(response) {
      // Reload on failure too, so the list never shows an order that wasn't saved.
      if (reload || !response.ok) window.location.reload();
    });
  },

  // Renumber the order badges and move the "Reviews page N" dividers to the
  // items that now end each Reviews-page group.
  renumber: function() {
    var number = this.offset();
    var total = parseInt(this.list.getAttribute('data-total'), 10);
    var size = parseInt(this.list.getAttribute('data-reviews-page-size'), 10);
    Array.prototype.forEach.call(this.list.children, function(li) {
      number++;
      li.querySelector('.order-number').textContent = number;
      if (number % size === 0 && number < total) {
        li.setAttribute('data-reviews-break', 'Reviews page ' + (number / size + 1));
      } else {
        li.removeAttribute('data-reviews-break');
      }
    });
  }
};
