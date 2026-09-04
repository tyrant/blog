(() => {
  const codeMirrorInstances = [];

  // JSON keys whose object/array value is collapsed on page load.
  const FOLD_BY_DEFAULT = ['body_json', 'blizzard'];

  const autoFold = (cm, keys) => {
    cm.operation(() => {
      for (let line = 0; line < cm.lineCount(); line++) {
        const text = cm.getLine(line);
        // force: "fold" — a later match nested inside an earlier fold (e.g.
        // body_json inside blizzard) must not toggle the outer fold back open.
        if (keys.some((key) => text.includes(`"${key}"`))) {
          cm.foldCode(CodeMirror.Pos(line, 0), null, 'fold');
        }
      }
    });
  };

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
        if (mode === 'application/json') {
          autoFold(codemirror, FOLD_BY_DEFAULT);
          // Collapse the top-level array/object (line 0) on load for editors
          // whose whole value is one big structure, e.g. the Substack footer.
          if (textarea.dataset.cmsCmFoldRoot != null) {
            codemirror.foldCode(CodeMirror.Pos(0, 0));
          }
        }
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
