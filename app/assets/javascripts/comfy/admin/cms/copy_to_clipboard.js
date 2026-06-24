(() => {
  window.CMS.clipboard = (root = document) => {
    root.querySelectorAll('.copy-blizzard-text').forEach((button) => {
      if (button.dataset.clipboardBound) return;
      button.dataset.clipboardBound = 'true';
      button.addEventListener('click', () => {
        const source = button.closest('.blizzard-copy')?.querySelector('.blizzard-text');
        if (source === null || source === undefined) return;
        navigator.clipboard.writeText(source.textContent).then(() => {
          const label = button.textContent;
          button.textContent = 'Copied!';
          setTimeout(() => { button.textContent = label; }, 1500);
        });
      });
    });
  };
})();
