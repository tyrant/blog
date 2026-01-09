(() => {
  const CMS = window.CMS;
  const AUTOSAVE_INTERVAL_MS = 120 * 1000;

  CMS.autosave = {
    timer: null,
    form: null,
    indicator: null,
    isSaving: false,

    init() {
      // Only init on blog post edit pages (not new - need an ID first)
      // URL pattern: /admin/sites/:site_id/blog-posts/:id
      this.form = document.querySelector('form[action*="/admin/"][action*="/blog-posts/"]');
      if (!this.form) return;

      // Only autosave existing posts (edit page), not new posts
      const isEditPage = this.form.action.includes('/blog-posts/') && 
                         !this.form.action.endsWith('/blog-posts');
      if (!isEditPage) return;

      this.createIndicator();
      this.startTimer();
      this.form.addEventListener('submit', () => this.stopTimer());
    },

    dispose() {
      this.stopTimer();
      if (this.indicator) {
        this.indicator.remove();
        this.indicator = null;
      }
    },

    createIndicator() {
      this.indicator = document.createElement('a');
      this.indicator.className = 'btn autosave-indicator text-muted float-right';
      
      const submitBtn = this.form.querySelector('input[type="submit"]');
      if (submitBtn && submitBtn.parentNode) {
        submitBtn.parentNode.insertBefore(this.indicator, submitBtn.parentNode.lastChild);
      }
    },

    startTimer() {
      this.stopTimer();
      this.timer = setInterval(() => this.save(), AUTOSAVE_INTERVAL_MS);
    },

    stopTimer() {
      if (this.timer) {
        clearInterval(this.timer);
        this.timer = null;
      }
    },

    syncEditors() {
      // Sync CodeMirror instances to their textareas
      if (CMS.codemirror && CMS.codemirror.editors) {
        CMS.codemirror.editors.forEach(editor => {
          if (editor && editor.save) editor.save();
        });
      }
      // Sync Redactor/WYSIWYG instances
      document.querySelectorAll('[data-cms-rich-text]').forEach(el => {
        if (el.redactor) {
          const textarea = document.querySelector(`#${el.dataset.cmsRichText}`);
          if (textarea) textarea.value = el.redactor.source.getCode();
        }
      });
    },

    async save() {
      if (this.isSaving) return;

      this.isSaving = true;
      this.updateIndicator('Saving...');

      try {
        this.syncEditors();

        const formData = new FormData(this.form);
        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;

        const response = await fetch(this.form.action + '.json', {
          method: 'PATCH',
          headers: {
            'X-CSRF-Token': csrfToken,
            'Accept': 'application/json'
          },
          body: formData
        });

        if (response.ok) {
          const time = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
          this.updateIndicator(`Autosaved at ${time}`);
        } else {
          const data = await response.json().catch(() => ({}));
          this.updateIndicator(`Autosave failed: ${data.error || 'Unknown error'}`, true);
        }
      } catch (error) {
        this.updateIndicator('Autosave failed: Network error', true);
        console.error('Autosave error:', error);
      } finally {
        this.isSaving = false;
      }
    },

    updateIndicator(text, isError = false) {
      if (!this.indicator) return;
      this.indicator.textContent = text;
      this.indicator.style.color = isError ? '#dc3545' : '#6c757d';
    }
  };
})();
