import { renderSubtitleTemplate } from './subtitle_template_render.js';

// Wires every [data-subtitle-sample] button to render its subtitle template with
// a random pick per variable and write the result to a readonly output field.
//
// Each button sources its template and variables JSON from either a live field
// (data-template-field / data-variables-field = element id, used on the config
// page where they're being edited) or a literal value (data-template /
// data-variables, used on the post edit page where the saved config is embedded).
// data-output is the id of the readonly field to write into.
window.CMS.substackSubtitleSample = {
  init: function () {
    this.buttons = Array.from(document.querySelectorAll('[data-subtitle-sample]'));
    this.handlers = new Map();
    this.buttons.forEach((btn) => {
      const handler = this.generate.bind(this, btn);
      this.handlers.set(btn, handler);
      btn.addEventListener('click', handler);
    });
  },

  dispose: function () {
    if (!this.handlers) return;
    this.handlers.forEach((handler, btn) => btn.removeEventListener('click', handler));
    this.handlers.clear();
  },

  generate: function (btn) {
    const template = btn.dataset.templateField
      ? this.fieldValue(btn.dataset.templateField)
      : btn.dataset.template;
    const variablesJson = btn.dataset.variablesField
      ? this.fieldValue(btn.dataset.variablesField)
      : btn.dataset.variables;

    const output = document.getElementById(btn.dataset.output);
    if (!output) return;

    const result = renderSubtitleTemplate(template, variablesJson);
    output.value = result.error ? result.error : result.output;
  },

  // The current value of a field by id. A CodeMirror-editing textarea only syncs
  // to its <textarea> on form submit, so read the live editor value when present
  // (its wrapper element is the textarea's next sibling and carries .CodeMirror).
  fieldValue: function (id) {
    const el = document.getElementById(id);
    if (!el) return '';
    const wrapper = el.nextElementSibling;
    if (wrapper && wrapper.CodeMirror) return wrapper.CodeMirror.getValue();
    return el.value;
  },
};
