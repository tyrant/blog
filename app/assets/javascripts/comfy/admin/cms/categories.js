(() => {
  window.CMS.categories = (root = document) => {
    root.querySelectorAll('.categorizations-widget .categorization-toggle').forEach((toggle) => {
      const fields = toggle.closest('li').querySelector('.categorization-fields');
      if (fields === null) return;
      toggle.addEventListener('change', () => {
        fields.style.display = toggle.checked ? 'block' : 'none';
      });
    });

    const widget = root.querySelector('.categories-widget');
    if (widget === null) return;
    const readSection = widget.querySelector('.read');
    const editSection = widget.querySelector('.editable');
    widget.querySelector('.read button.toggle-cat-edit').addEventListener('click', () => {
      readSection.style.display = 'none';
      editSection.style.display = 'block';
    });
    widget.querySelector('.editable button.toggle-cat-edit').addEventListener('click', () => {
      editSection.style.display = 'none';
      readSection.style.display = 'block';
    });
  };
})();

