window.CMS.mediumExport = {
  init: function() {
    this.button = document.getElementById('copy-for-medium');
    if (!this.button) return;

    this.originalLabel = this.button.textContent;
    this.button.addEventListener('click', this.copyForMedium.bind(this));
  },

  dispose: function() {
    if (this.button) {
      this.button.removeEventListener('click', this.copyForMedium.bind(this));
    }
  },

  copyForMedium: function() {
    this.button.disabled = true;

    // Get banner URL from data attribute (includes digest)
    const bannerUrl = this.button.dataset.bannerUrl;

    // Get the wysiwyg content - sync from Redactor first if available
    this.syncEditors();

    // Find the content fragment textarea
    const contentTextarea = document.querySelector('textarea[data-cms-rich-text]');
    const content = contentTextarea ? contentTextarea.value : '';

    if (!content) {
      this.showStatus('No content to copy', 'error');
      return;
    }

    // Format for Medium: title, banner image, then content
    const bannerImg = `<img src="${bannerUrl}" alt="Bad Advice from the Sexyverse">`;
    const html = `<p>${bannerImg}</p>\n${content}`;

    // Copy to clipboard as HTML
    this.copyHtmlToClipboard(html);
  },

  syncEditors: function() {
    // Sync Redactor editors
    if (typeof $R !== 'undefined') {
      document.querySelectorAll('textarea[data-cms-rich-text]').forEach(function(textarea) {
        const redactor = $R(textarea, 'source.getCode');
        if (redactor) {
          textarea.value = redactor;
        }
      });
    }
  },

  copyHtmlToClipboard: function(html) {
    const self = this;

    // Use the Clipboard API with HTML mime type
    if (navigator.clipboard && navigator.clipboard.write) {
      const blob = new Blob([html], { type: 'text/html' });
      const clipboardItem = new ClipboardItem({ 'text/html': blob });

      navigator.clipboard.write([clipboardItem]).then(function() {
        self.showStatus('Post content copied!', 'success');
      }).catch(function(err) {
        console.error('Clipboard write failed:', err);
        self.fallbackCopy(html);
      });
    } else {
      this.fallbackCopy(html);
    }
  },

  fallbackCopy: function(html) {
    // Fallback: copy as plain text
    const textarea = document.createElement('textarea');
    textarea.value = html;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();

    try {
      document.execCommand('copy');
      this.showStatus('Copied (as text)', 'success');
    } catch (err) {
      this.showStatus('Copy failed', 'error');
    }

    document.body.removeChild(textarea);
  },

  // Status shows in the button's own label, restoring the original label — and
  // re-enabling the button — after 3 seconds.
  showStatus: function(message, type) {
    var self = this;
    if (this._restoreTimer) { clearTimeout(this._restoreTimer); this._restoreTimer = null; }
    this.button.textContent = message;

    this._restoreTimer = setTimeout(function() {
      self.button.textContent = self.originalLabel;
      self.button.disabled = false;
      self._restoreTimer = null;
    }, 3000);
  }
};
