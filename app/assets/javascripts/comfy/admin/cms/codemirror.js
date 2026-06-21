(() => {
  const codeMirrorInstances = [];
  window.CMS.codemirror = {
    init(root = document) {
      for (const textarea of root.querySelectorAll('textarea[data-cms-cm-mode]')) {
        const mode = textarea.dataset.cmsCmMode;
        const options = {
          mode,
          tabSize: 2,
          lineWrapping: true,
          autoCloseTags: true,
          lineNumbers: true,
          viewportMargin: Infinity
        };
        // Collapsible +/- gutter for JSON structures (arrays/objects).
        if (mode === 'application/json') {
          options.foldGutter = true;
          options.gutters = ['CodeMirror-linenumbers', 'CodeMirror-foldgutter'];
        }
        const codemirror = CodeMirror.fromTextArea(textarea, options);
        codeMirrorInstances.push(codemirror);
      }

      const tabsRoot = root.id === 'form-fragments' ? root : root.querySelector('#form-fragments');
      jQuery(tabsRoot).find('a[data-toggle="tab"]').on('shown.bs.tab', () => {
        for (const codemirror of codeMirrorInstances) {
          codemirror.refresh();
        }
      });
    },
    dispose() {
      for (const codemirror of codeMirrorInstances) {
        codemirror.toTextArea();
      }
      codeMirrorInstances.length = 0;
    }
}
})();
