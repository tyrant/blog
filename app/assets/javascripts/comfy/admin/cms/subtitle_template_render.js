// Renders a subtitle template client-side for the "generate sample" button:
// each {{ var }} is replaced by a random value from variables[var] (an array of
// strings). Missing/empty variables leave the token untouched, mirroring the
// server-side Substack::SubtitleTemplate. Returns { output } on success or
// { error } if the variables JSON is unparseable.
export function renderSubtitleTemplate(template, variablesJson) {
  let variables = {};
  const raw = (variablesJson || '').trim();
  if (raw) {
    try {
      variables = JSON.parse(raw);
    } catch (e) {
      return { error: 'Variables JSON is invalid: ' + e.message };
    }
    if (typeof variables !== 'object' || Array.isArray(variables) || variables === null) {
      return { error: 'Variables JSON must be an object of { key: [values] }.' };
    }
  }

  const output = String(template || '').replace(/\{\{\s*(\w+)\s*\}\}/g, function (token, key) {
    const values = variables[key];
    if (Array.isArray(values) && values.length) {
      return String(values[Math.floor(Math.random() * values.length)]);
    }
    return token;
  });
  return { output };
}
