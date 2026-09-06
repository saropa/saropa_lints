/**
 * Unit tests for the l10n diagnostic parser functions.
 * Covers string skipping, comment blanking, param-block extraction,
 * and top-level key detection — including edge cases that caused
 * false positives before the state-machine rewrite.
 */
import * as assert from 'node:assert';
import {
  OPAQUE_PARAMS,
  skipStringLiteral,
  blankComments,
  extractBalancedBrace,
  extractParamsBlock,
  extractTopLevelKeys,
} from '../i18n/l10nParsers';

// -- skipStringLiteral -------------------------------------------------------

describe('skipStringLiteral', () => {
  it('skips a single-quoted string', () => {
    const text = "'hello' rest";
    assert.strictEqual(skipStringLiteral(text, 0), 7);
  });

  it('skips a double-quoted string', () => {
    const text = '"hello" rest';
    assert.strictEqual(skipStringLiteral(text, 0), 7);
  });

  it('handles escaped quotes inside string', () => {
    const text = "'he\\'llo' rest";
    assert.strictEqual(skipStringLiteral(text, 0), 9);
  });

  it('skips a simple template literal', () => {
    const text = '`hello` rest';
    assert.strictEqual(skipStringLiteral(text, 0), 7);
  });

  it('handles template literal with ${} interpolation', () => {
    const text = '`a ${x} b` rest';
    assert.strictEqual(skipStringLiteral(text, 0), 10);
  });

  it('handles nested template literal inside interpolation', () => {
    // `outer ${`inner`} end`
    const text = '`outer ${`inner`} end` rest';
    assert.strictEqual(skipStringLiteral(text, 0), 22);
  });

  it('handles nested braces inside interpolation', () => {
    // `${fn({a: 1})}` — the {a: 1} inside interpolation must not
    // close the interpolation prematurely.
    const text = '`${fn({a: 1})}` rest';
    assert.strictEqual(skipStringLiteral(text, 0), 15);
  });

  it('handles string inside interpolation', () => {
    // `${"don't"}` — single quote inside double-quoted string
    // inside interpolation must not confuse the scanner.
    const text = '`${"don\'t"}` rest';
    assert.strictEqual(skipStringLiteral(text, 0), 12);
  });

  it('returns text length for unterminated string', () => {
    assert.strictEqual(skipStringLiteral("'unterminated", 0), 13);
  });
});

// -- blankComments -----------------------------------------------------------

describe('blankComments', () => {
  it('blanks a line comment', () => {
    const result = blankComments('code // comment\nmore');
    assert.strictEqual(result, 'code           \nmore');
  });

  it('blanks a block comment', () => {
    const result = blankComments('a /* block */ b');
    assert.strictEqual(result, 'a             b');
  });

  it('preserves newlines inside block comments', () => {
    const result = blankComments('a /*\n*/ b');
    assert.strictEqual(result, 'a   \n   b');
  });

  it('does not blank // inside a string', () => {
    const result = blankComments("const s = '// not a comment';");
    assert.strictEqual(result, "const s = '// not a comment';");
  });

  it('does not blank /* inside a template literal', () => {
    const result = blankComments('const s = `/* nope */`;');
    assert.strictEqual(result, 'const s = `/* nope */`;');
  });

  it('skips regex literals without treating them as comments', () => {
    // x = /pattern/g should not be treated as starting a comment.
    const result = blankComments('x = /pattern/g; // comment');
    // The regex is preserved, the comment is blanked.
    assert.ok(result.includes('/pattern/g'));
    assert.ok(!result.includes('comment'));
  });

  it('preserves string length for position mapping', () => {
    const input = 'a // hello\nb /* world */ c';
    assert.strictEqual(blankComments(input).length, input.length);
  });

  it('handles regex with character class containing /', () => {
    // x = /[a/b]/g — the / inside [] should not end the regex.
    const result = blankComments('x = /[a/b]/g; // comment');
    assert.ok(result.includes('/[a/b]/g'));
    assert.ok(!result.includes('comment'));
  });
});

// -- extractParamsBlock ------------------------------------------------------

describe('extractParamsBlock', () => {
  it('extracts a simple params object', () => {
    const text = "l10n('key', { count })";
    // afterKey points to just after the closing quote.
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    assert.strictEqual(extractParamsBlock(text, afterKey), '{ count }');
  });

  it('extracts params with nested function calls', () => {
    const text = "l10n('key', { count: String(n) })";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    assert.strictEqual(extractParamsBlock(text, afterKey), '{ count: String(n) }');
  });

  it('returns undefined when no params passed', () => {
    const text = "l10n('key')";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    assert.strictEqual(extractParamsBlock(text, afterKey), undefined);
  });

  it('handles strings with braces inside params', () => {
    const text = "l10n('key', { msg: '{hello}' })";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    const result = extractParamsBlock(text, afterKey);
    assert.strictEqual(result, "{ msg: '{hello}' }");
  });

  it('returns OPAQUE_PARAMS for a variable reference', () => {
    // l10n('key', params) — second arg is an identifier, not an object literal.
    const text = "l10n('key', params)";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    assert.strictEqual(extractParamsBlock(text, afterKey), OPAQUE_PARAMS);
  });

  it('returns OPAQUE_PARAMS for a property access', () => {
    // l10n('key', band.params) — second arg is a dotted expression.
    const text = "l10n('key', band.params)";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    assert.strictEqual(extractParamsBlock(text, afterKey), OPAQUE_PARAMS);
  });

  it('returns OPAQUE_PARAMS for a function call', () => {
    // l10n('key', getParams()) — second arg is a call expression.
    const text = "l10n('key', getParams())";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    assert.strictEqual(extractParamsBlock(text, afterKey), OPAQUE_PARAMS);
  });

  it('returns OPAQUE_PARAMS for a ternary expression', () => {
    // l10n('key', cond ? a : b) — second arg is a conditional expression.
    const text = "l10n('key', cond ? paramsA : paramsB)";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    assert.strictEqual(extractParamsBlock(text, afterKey), OPAQUE_PARAMS);
  });

  it('returns undefined for undefined as second arg', () => {
    // l10n('key', undefined) — functionally no params, not opaque.
    const text = "l10n('key', undefined)";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    assert.strictEqual(extractParamsBlock(text, afterKey), undefined);
  });

  it('returns undefined for null as second arg', () => {
    // l10n('key', null) — functionally no params, not opaque.
    const text = "l10n('key', null)";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    assert.strictEqual(extractParamsBlock(text, afterKey), undefined);
  });

  it('returns OPAQUE_PARAMS for a spread-into-object expression', () => {
    // l10n('key', { ...base, extra }) uses { so it should parse normally —
    // but a bare spread variable like `...params` is still an inline object.
    const text = "l10n('key', { ...base, extra })";
    const afterKey = text.indexOf("'", text.indexOf("'") + 1) + 1;
    // Starts with { so extractParamsBlock parses the inline object.
    assert.strictEqual(extractParamsBlock(text, afterKey), '{ ...base, extra }');
  });
});

// -- extractBalancedBrace ----------------------------------------------------

describe('extractBalancedBrace', () => {
  it('extracts a simple object literal', () => {
    assert.strictEqual(extractBalancedBrace('{ a: 1 }', 0), '{ a: 1 }');
  });

  it('handles nested braces', () => {
    assert.strictEqual(extractBalancedBrace('{ a: { b: 1 } }', 0), '{ a: { b: 1 } }');
  });

  it('returns undefined when not starting at a brace', () => {
    assert.strictEqual(extractBalancedBrace('abc', 0), undefined);
  });

  it('returns undefined for out-of-bounds position', () => {
    assert.strictEqual(extractBalancedBrace('{}', 5), undefined);
  });

  it('skips braces inside string literals', () => {
    // The { inside the string shouldn't affect depth tracking.
    assert.strictEqual(extractBalancedBrace("{ msg: '{hello}' }", 0), "{ msg: '{hello}' }");
  });

  it('skips braces inside template literal interpolations', () => {
    // The ${...} inside the template should not confuse brace depth.
    const text = '{ msg: `${fn({x: 1})}` }';
    assert.strictEqual(extractBalancedBrace(text, 0), text);
  });

  it('returns undefined for unterminated block', () => {
    assert.strictEqual(extractBalancedBrace('{ a: 1', 0), undefined);
  });

  it('extracts from a mid-string position', () => {
    // Starting at position 5 which is the { of the nested object.
    const text = 'xxx { a: 1 } yyy';
    assert.strictEqual(extractBalancedBrace(text, 4), '{ a: 1 }');
  });
});

// -- extractTopLevelKeys -----------------------------------------------------

describe('extractTopLevelKeys', () => {
  it('extracts shorthand keys', () => {
    const keys = extractTopLevelKeys('{ a, b, c }');
    assert.deepStrictEqual([...keys].sort(), ['a', 'b', 'c']);
  });

  it('extracts explicit keys', () => {
    const keys = extractTopLevelKeys('{ count: String(n), name: x }');
    assert.deepStrictEqual([...keys].sort(), ['count', 'name']);
  });

  it('extracts mix of shorthand and explicit keys', () => {
    const keys = extractTopLevelKeys('{ verb, count: String(rules.length) }');
    assert.deepStrictEqual([...keys].sort(), ['count', 'verb']);
  });

  it('handles trailing comma', () => {
    const keys = extractTopLevelKeys('{ a, b, }');
    assert.deepStrictEqual([...keys].sort(), ['a', 'b']);
  });

  it('does not treat spread operand as a key', () => {
    const keys = extractTopLevelKeys('{ ...defaults, count }');
    assert.deepStrictEqual([...keys], ['count']);
  });

  it('does not treat spread member-access as keys', () => {
    // ...obj.nested.path should not produce obj, nested, or path.
    const keys = extractTopLevelKeys('{ ...obj.nested.path, count }');
    assert.deepStrictEqual([...keys], ['count']);
  });

  it('does not treat spread function-call results as keys', () => {
    // ...getDefaults().overrides — the full expression is consumed.
    const keys = extractTopLevelKeys('{ ...getDefaults().overrides, name }');
    assert.deepStrictEqual([...keys], ['name']);
  });

  it('ignores value identifiers inside nested expressions', () => {
    // String and n are inside a call expression, not keys.
    const keys = extractTopLevelKeys('{ count: String(n) }');
    assert.deepStrictEqual([...keys], ['count']);
  });

  it('ignores identifiers inside nested objects', () => {
    const keys = extractTopLevelKeys('{ a: { x: 1 }, b }');
    assert.deepStrictEqual([...keys].sort(), ['a', 'b']);
  });

  it('handles string values containing braces', () => {
    const keys = extractTopLevelKeys("{ msg: '{hello}', count }");
    assert.deepStrictEqual([...keys].sort(), ['count', 'msg']);
  });

  it('handles template literal values', () => {
    const keys = extractTopLevelKeys('{ msg: `${x}`, count }');
    assert.deepStrictEqual([...keys].sort(), ['count', 'msg']);
  });

  it('handles single key', () => {
    const keys = extractTopLevelKeys('{ count }');
    assert.deepStrictEqual([...keys], ['count']);
  });

  it('handles single explicit key', () => {
    const keys = extractTopLevelKeys('{ pageSize: String(PAGE_SIZE) }');
    assert.deepStrictEqual([...keys], ['pageSize']);
  });
});
