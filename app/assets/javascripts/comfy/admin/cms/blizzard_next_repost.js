(() => {
  if (!window.CMS) window.CMS = {};

  window.CMS.blizzardNextRepost = (root = document) => {
    const container = document.getElementById('next-repost-suggestion');
    if (!container) return;

    container.querySelectorAll('form').forEach((form) => {
      if (form.dataset.blizzardAjaxBound) return;
      form.dataset.blizzardAjaxBound = 'true';
      form.addEventListener('submit', (event) => {
        event.preventDefault();
        submitForm(form);
      });
    });

    root.querySelectorAll('.regenerate-suggestion').forEach((button) => {
      if (button.dataset.regenerateBound) return;
      button.dataset.regenerateBound = 'true';
      button.addEventListener('click', () => regenerate(button));
    });
  };

  function submitForm(form) {
    const status = statusEl(form);
    // rails-ujs (loaded and Rails.start()'d for the main site's forms) binds its
    // own submit listener to every form regardless of this one being intercepted,
    // and disables the data-disable-with button expecting a real navigation to
    // reset it. Since we replace that navigation with a fetch, nothing ever would —
    // so re-enable it ourselves once the request settles, success or failure.
    const button = form.querySelector('[type="submit"]');
    status.textContent = '';
    status.classList.remove('text-danger');

    fetch(form.action, {
      method: 'POST',
      body: new FormData(form),
      headers: { Accept: 'application/json' },
    })
      .then((response) => response.json().then((data) => ({ ok: response.ok, data })))
      .then(({ ok, data }) => {
        if (ok && data.success) {
          onFormSuccess(form, data, status);
        } else {
          status.textContent = data.error || 'Could not save.';
          status.classList.add('text-danger');
        }
      })
      .catch(() => {
        status.textContent = 'Network error.';
        status.classList.add('text-danger');
      })
      .finally(() => {
        if (button) button.disabled = false;
      });
  }

  function onFormSuccess(form, data, status) {
    if ('html' in data) {
      const container = document.getElementById('next-repost-suggestion');
      const textEl = container && container.querySelector('.blizzard-text');
      const htmlEl = container && container.querySelector('.blizzard-html');
      if (textEl) textEl.textContent = data.text;
      if (htmlEl) htmlEl.innerHTML = data.html;
      status.textContent = 'Re-seeded!';
    } else {
      status.textContent = 'Recorded!';
    }
    form.reset();
    setTimeout(() => { status.textContent = ''; }, 2500);
  }

  function statusEl(form) {
    let el = form.querySelector('.blizzard-ajax-status');
    if (!el) {
      el = document.createElement('span');
      el.className = 'blizzard-ajax-status small ml-2';
      form.appendChild(el);
    }
    return el;
  }

  function regenerate(button) {
    const container = document.getElementById('next-repost-suggestion');
    if (!container) return;

    button.disabled = true;
    fetch(button.dataset.url, { headers: { Accept: 'text/html' } })
      .then((response) => response.text())
      .then((html) => {
        container.innerHTML = html;
        window.CMS.clipboard(container);
        window.CMS.blizzardNextRepost(container);
      })
      .finally(() => { button.disabled = false; });
  }
})();
