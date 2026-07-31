window.CMS.blueskySync = {
  init: function() {
    this.button = document.getElementById('sync-to-bluesky');
    if (!this.button) return;

    this.originalLabel = this.button.textContent;
    this.button.addEventListener('click', this.syncToBluesky.bind(this));
  },

  dispose: function() {
    if (this.button) {
      this.button.removeEventListener('click', this.syncToBluesky.bind(this));
    }
  },

  syncToBluesky: function() {
    var self = this;
    var syncUrl = this.button.dataset.syncUrl;
    var csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    this.button.disabled = true;
    this.showStatus('Syncing to Bluesky…', 'info');

    fetch(syncUrl, {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrfToken, 'Content-Type': 'application/json' }
    })
    .then(function(res) { return res.json(); })
    .then(function(data) {
      self.showStatus(data.success ? 'Sync started!' : 'Error: ' + (data.message || 'Unknown error'),
                      data.success ? 'success' : 'error');
    })
    .catch(function() {
      self.showStatus('Request failed', 'error');
    });
  },

  // Status shows in the button's own label. An 'info' (in-progress) message
  // persists until the next status replaces it; a final message restores the
  // original label — and re-enables the button — after 3 seconds.
  showStatus: function(message, type) {
    var self = this;
    if (this._restoreTimer) { clearTimeout(this._restoreTimer); this._restoreTimer = null; }
    this.button.textContent = message;
    if (type === 'info') return;

    this._restoreTimer = setTimeout(function() {
      self.button.textContent = self.originalLabel;
      self.button.disabled = false;
      self._restoreTimer = null;
    }, 3000);
  }
};
