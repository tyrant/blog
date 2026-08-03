import { describe, it, expect, vi } from 'vitest';
import { renderSubtitleTemplate } from './subtitle_template_render.js';

describe('renderSubtitleTemplate', () => {
  it('substitutes a token with a value from its array', () => {
    expect(renderSubtitleTemplate('Hi {{ name }}', '{"name":["there"]}').output).toBe('Hi there');
  });

  it('substitutes every token', () => {
    expect(renderSubtitleTemplate('{{ a }}-{{ b }}', '{"a":["1"],"b":["2"]}').output).toBe('1-2');
  });

  it('tolerates whitespace inside the braces', () => {
    expect(renderSubtitleTemplate('{{x}} {{   x   }}', '{"x":["q"]}').output).toBe('q q');
  });

  it('always renders a value drawn from the array', () => {
    for (let i = 0; i < 30; i++) {
      expect(['a', 'b', 'c']).toContain(renderSubtitleTemplate('{{ x }}', '{"x":["a","b","c"]}').output);
    }
  });

  it('picks by index from Math.random', () => {
    vi.spyOn(Math, 'random').mockReturnValue(0.99);
    expect(renderSubtitleTemplate('{{ x }}', '{"x":["a","b","c"]}').output).toBe('c');
    Math.random.mockRestore();
  });

  it('upper-cases the compliment variable value', () => {
    expect(renderSubtitleTemplate('{{ compliment }}', '{"compliment":["lovely"]}').output).toBe('LOVELY');
  });

  it('does not upper-case other variables', () => {
    expect(renderSubtitleTemplate('{{ other }}', '{"other":["lovely"]}').output).toBe('lovely');
  });

  it('leaves a token whose variable is missing', () => {
    expect(renderSubtitleTemplate('a {{ missing }} b', '{}').output).toBe('a {{ missing }} b');
  });

  it('leaves a token whose array is empty', () => {
    expect(renderSubtitleTemplate('{{ x }}', '{"x":[]}').output).toBe('{{ x }}');
  });

  it('treats a blank variables string as no variables', () => {
    expect(renderSubtitleTemplate('{{ x }}', '').output).toBe('{{ x }}');
  });

  it('returns an error for unparseable JSON', () => {
    expect(renderSubtitleTemplate('{{ x }}', 'not json').error).toMatch(/invalid/i);
  });

  it('returns an error when the JSON is not an object', () => {
    expect(renderSubtitleTemplate('{{ x }}', '[1,2,3]').error).toMatch(/object/i);
  });

  it('renders the sample subtitle from the brief', () => {
    const tpl = "Sexyverse Advice: {{ country }}'s {{ superlative }} {{ pejorative }} {{ source }}.";
    const vars = JSON.stringify({
      country: ['Narnia', 'Japan', 'NZ', 'Mali'],
      superlative: ['superb-est', 'prettiest', 'snazziest', 'finest'],
      pejorative: ['BS', 'nonsense', 'wank'],
      source: ['fountain', 'volcano', 'dervish', 'tornado', 'oasis'],
    });
    expect(renderSubtitleTemplate(tpl, vars).output).toMatch(
      /^Sexyverse Advice: (Narnia|Japan|NZ|Mali)'s (superb-est|prettiest|snazziest|finest) (BS|nonsense|wank) (fountain|volcano|dervish|tornado|oasis)\.$/
    );
  });
});
