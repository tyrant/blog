window.CMS.mediumSync = {
  init: function() {
    this.button = document.getElementById('sync-to-medium');
    if (!this.button) return;

    this.statusEl = document.querySelector('.medium-sync-status');
    this.button.addEventListener('click', this.syncToMedium.bind(this));
  },

  dispose: function() {
    if (this.button) {
      this.button.removeEventListener('click', this.syncToMedium.bind(this));
    }
  },

  syncToMedium: function() {
    var self = this;
    var syncUrl = this.button.dataset.syncUrl;
    var csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    this.button.disabled = true;
    this.showStatus('Syncing to Medium\u2026', 'info');

    fetch(syncUrl, {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrfToken, 'Content-Type': 'application/json' }
    })
    .then(function(res) { return res.json(); })
    .then(function(data) {
      if (data.success) {
        self.showStatus('Synced!', 'success');
      } else {
        self.showStatus('Error: ' + (data.message || 'Unknown error'), 'error');
      }
      self.button.disabled = false;
    })
    .catch(function() {
      self.showStatus('Request failed', 'error');
      self.button.disabled = false;
    });
  },

  showStatus: function(message, type) {
    if (!this.statusEl) return;
    var colours = { success: '#28a745', error: '#dc3545', info: '#6c757d' };
    this.statusEl.textContent = message;
    this.statusEl.style.display = 'inline';
    this.statusEl.style.color = colours[type] || colours.info;
  }
};
