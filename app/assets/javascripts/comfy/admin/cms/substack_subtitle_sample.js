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
      ? (document.getElementById(btn.dataset.templateField) || {}).value
      : btn.dataset.template;
    const variablesJson = btn.dataset.variablesField
      ? (document.getElementById(btn.dataset.variablesField) || {}).value
      : btn.dataset.variables;

    const output = document.getElementById(btn.dataset.output);
    if (!output) return;

    const result = renderSubtitleTemplate(template, variablesJson);
    output.value = result.error ? result.error : result.output;
  },
};
