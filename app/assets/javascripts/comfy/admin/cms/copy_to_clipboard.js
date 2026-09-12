(() => {
  window.CMS.clipboard = (root = document) => {
    root.querySelectorAll('.copy-blizzard-text').forEach((button) => {
      if (button.dataset.clipboardBound) return;
      button.dataset.clipboardBound = 'true';
      button.addEventListener('click', () => {
        const container = button.closest('.blizzard-copy');
        const textSource = container?.querySelector('.blizzard-text');
        const htmlSource = container?.querySelector('.blizzard-html');
        if (textSource === null || textSource === undefined) return;

        const text = textSource.textContent;
        const confirmCopied = () => {
          const label = button.textContent;
          button.textContent = 'Copied!';
          setTimeout(() => { button.textContent = label; }, 1500);
        };

        if (window.ClipboardItem && navigator.clipboard.write) {
          const html = htmlSource ? htmlSource.innerHTML : text;
          const item = new ClipboardItem({
            'text/plain': new Blob([text], { type: 'text/plain' }),
            'text/html': new Blob([html], { type: 'text/html' }),
          });
          navigator.clipboard.write([item]).then(confirmCopied);
        } else {
          navigator.clipboard.writeText(text).then(confirmCopied);
        }
      });
    });
  };
})();
