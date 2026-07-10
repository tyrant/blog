window.CMS.replyDrafter = {
  init: function() {
    this.button = document.getElementById('reply-generate');
    if (!this.button) return;

    this.urlInput = document.getElementById('reply-post-url');
    this.instructions = document.getElementById('reply-instructions');
    this.count = document.getElementById('reply-count');
    this.split = document.getElementById('reply-split');
    this.length = document.getElementById('reply-length');
    this.model = document.getElementById('reply-model');
    this.status = document.getElementById('reply-status');
    this.results = document.getElementById('reply-results');
    this.originalLabel = this.button.innerHTML;
    this.button.addEventListener('click', this.generate.bind(this));
  },

  SPINNER: '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>',

  dispose: function() {
    if (this.button) {
      this.button.removeEventListener('click', this.generate.bind(this));
    }
  },

  generate: function() {
    var self = this;
    var url = this.urlInput.value.trim();
    if (!url) {
      this.setStatus('Enter a Substack post URL first.');
      this.urlInput.focus();
      return;
    }

    var csrf = document.querySelector('meta[name="csrf-token"]').content;
    this.button.disabled = true;
    this.button.innerHTML = this.SPINNER;
    this.results.innerHTML = '';
    this.setStatus('Reading the post and drafting replies…');

    fetch(this.button.dataset.url, {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        url: url,
        instructions: this.instructions.value,
        count: this.count.value,
        split: this.split.value,
        length: this.length.value,
        model: this.model.value
      })
    })
    .then(function(res) { return res.json().then(function(body) { return { ok: res.ok, body: body }; }); })
    .then(function(res) {
      self.button.disabled = false;
      self.button.innerHTML = self.originalLabel;
      if (!res.ok) { self.setStatus('Error: ' + (res.body.error || 'generation failed')); return; }
      var replies = res.body.replies || [];
      self.render(replies);
      self.setStatus(replies.length + ' drafts');
    })
    .catch(function() {
      self.button.disabled = false;
      self.button.innerHTML = self.originalLabel;
      self.setStatus('Request failed');
    });
  },

  render: function(replies) {
    var self = this;
    this.results.innerHTML = '';
    replies.forEach(function(reply) {
      var card = document.createElement('div');
      card.className = 'card mb-2';

      var body = document.createElement('div');
      body.className = 'card-body p-2';

      var copy = document.createElement('button');
      copy.type = 'button';
      copy.className = 'btn btn-sm btn-outline-secondary float-right ml-2';
      copy.textContent = 'Copy';
      copy.addEventListener('click', function() {
        navigator.clipboard.writeText(reply.text).then(function() {
          copy.textContent = 'Copied';
          setTimeout(function() { copy.textContent = 'Copy'; }, 2000);
        });
      });

      var badge = document.createElement('span');
      badge.className = 'badge mr-2 ' + (reply.stance === 'disagree' ? 'badge-warning' : 'badge-success');
      badge.textContent = reply.stance;

      var text = document.createElement('span');
      text.textContent = reply.text;

      body.appendChild(copy);
      body.appendChild(badge);
      body.appendChild(text);
      card.appendChild(body);
      self.results.appendChild(card);
    });
  },

  setStatus: function(message) {
    this.status.style.display = 'block';
    this.status.textContent = message;
  }
};
