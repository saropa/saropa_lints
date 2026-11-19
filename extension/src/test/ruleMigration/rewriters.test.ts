import * as assert from 'node:assert';
import { buildRenameMap, rewriteBaseline, rewriteDartIgnores, rewriteYamlKeys } from '../../ruleMigration/rewriters';

const map = buildRenameMap([
  { old: 'foo', new: 'foo_extended', since: '17.0.0' },
  { old: 'gone', new: null, since: '17.0.0' },
  { old: 'a', new: 'b', since: '17.0.0' },
  { old: 'b', new: 'c', since: '17.1.0' },
]);

describe('buildRenameMap', () => {
  it('collapses chains', () => {
    assert.strictEqual(map.get('a'), 'c');
    assert.strictEqual(map.get('b'), 'c');
  });
  it('does not loop on cycles', () => {
    const m = buildRenameMap([
      { old: 'x', new: 'y', since: '1.0.0' },
      { old: 'y', new: 'x', since: '1.0.0' },
    ]);
    assert.ok(m.size <= 2);
  });
});

describe('rewriteDartIgnores', () => {
  it('renames prefixed names in comma lists, hyphen spellings and ignore_for_file', () => {
    const src = 'a(); // ignore: saropa_lints/foo, other_lint\n// ignore_for_file: saropa_lints/foo, saropa_lints/gone\nb(); // ignore: saropa_lints/foo\n';
    const r = rewriteDartIgnores(src, map);
    assert.strictEqual(
      r.text,
      'a(); // ignore: saropa_lints/foo_extended, other_lint\n// ignore_for_file: saropa_lints/foo_extended\nb(); // ignore: saropa_lints/foo_extended\n',
    );
    assert.strictEqual(r.hits, 4);
    assert.strictEqual(rewriteDartIgnores('// ignore: saropa_lints/a, saropa_lints/b\n', map).text, '// ignore: saropa_lints/c\n');
    const hy = buildRenameMap([{ old: 'avoid_x_y', new: 'avoid_x_y_two', since: '1.0.0' }]);
    assert.strictEqual(rewriteDartIgnores('x; // ignore: saropa_lints/avoid-x-y\n', hy).text, 'x; // ignore: saropa_lints/avoid-x-y-two\n');
  });
  it('is idempotent and never doubles the suffix', () => {
    const once = rewriteDartIgnores('// ignore: saropa_lints/foo\n', map).text;
    const twice = rewriteDartIgnores(once, map);
    assert.strictEqual(twice.text, once);
    assert.strictEqual(twice.hits, 0);
  });
  it('removes removed rules and deletes an emptied comment', () => {
    assert.strictEqual(rewriteDartIgnores('// ignore: saropa_lints/gone, saropa_lints/foo\n', map).text, '// ignore: saropa_lints/foo_extended\n');
    assert.strictEqual(rewriteDartIgnores('keep();\n  // ignore: saropa_lints/gone\nnext();\n', map).text, 'keep();\nnext();\n');
    assert.strictEqual(rewriteDartIgnores('call(); // ignore: saropa_lints/gone\n', map).text, 'call();\n');
  });
  it('leaves bare old names alone and reports them', () => {
    const src = '// ignore: foo\n';
    const r = rewriteDartIgnores(src, map);
    assert.strictEqual(r.text, src);
    assert.deepStrictEqual(r.findings, [{ kind: 'bareName', name: 'foo', line: 1 }]);
  });
  it('keeps CRLF', () => {
    assert.strictEqual(rewriteDartIgnores('x;\r\n// ignore: saropa_lints/foo\r\ny;\r\n', map).text, 'x;\r\n// ignore: saropa_lints/foo_extended\r\ny;\r\n');
  });
  it('drops a duplicate when the new name is already listed', () => {
    assert.strictEqual(rewriteDartIgnores('// ignore: saropa_lints/foo, saropa_lints/foo_extended\n', map).text, '// ignore: saropa_lints/foo_extended\n');
  });
});

const OPTIONS = [
  'analyzer:',
  '  errors:',
  '    foo: ignore',
  'plugins:',
  '  saropa_lints:',
  '    version: "17.0.0"',
  '    diagnostics:',
  '      foo: true',
  '      gone:',
  '        severity: warning',
  '      keep: false',
  '',
].join('\n');

describe('rewriteYamlKeys', () => {
  it('rewrites only diagnostics keys, never analyzer errors', () => {
    const r = rewriteYamlKeys(OPTIONS, map);
    assert.strictEqual(
      r.text,
      ['analyzer:', '  errors:', '    foo: ignore', 'plugins:', '  saropa_lints:', '    version: "17.0.0"', '    diagnostics:', '      foo_extended: true', '      keep: false', ''].join('\n'),
    );
    assert.strictEqual(r.hits, 2);
  });
  it('is idempotent', () => {
    const once = rewriteYamlKeys(OPTIONS, map).text;
    assert.strictEqual(rewriteYamlKeys(once, map).text, once);
  });
  it('keeps new and drops old on a clash, and reports it', () => {
    const src = 'plugins:\n  saropa_lints:\n    diagnostics:\n      foo: true\n      foo_extended: false\n';
    const r = rewriteYamlKeys(src, map);
    assert.strictEqual(r.text, 'plugins:\n  saropa_lints:\n    diagnostics:\n      foo_extended: false\n');
    assert.deepStrictEqual(r.findings, [{ kind: 'clash', name: 'foo', line: 4 }]);
  });
  it('keeps CRLF and quotes', () => {
    const src = 'plugins:\r\n  saropa_lints:\r\n    diagnostics:\r\n      "foo": true\r\n';
    assert.strictEqual(rewriteYamlKeys(src, map).text, 'plugins:\r\n  saropa_lints:\r\n    diagnostics:\r\n      "foo_extended": true\r\n');
  });
  it('ignores files without a diagnostics block', () => {
    const src = 'plugins:\n  saropa_lints:\n    version: 1.0.0\nfoo: true\n';
    assert.strictEqual(rewriteYamlKeys(src, map).hits, 0);
  });
  it('custom mode rewrites top-level keys only', () => {
    const src = 'max_issues: 1\nfoo: true\ngone: false\nplatforms:\n  foo: true\n';
    assert.strictEqual(rewriteYamlKeys(src, map, 'custom').text, 'max_issues: 1\nfoo_extended: true\nplatforms:\n  foo: true\n');
  });
});

describe('rewriteBaseline', () => {
  const base = JSON.stringify({ version: 1, violations: { 'lib/a.dart': { foo: [3, 1], keep: [2], gone: [9] }, 'lib/b.dart': { foo: [1], foo_extended: [5, 1] } } }, null, 2) + '\n';
  it('renames, removes and merges line lists', () => {
    const r = rewriteBaseline(base, map);
    assert.deepStrictEqual(JSON.parse(r.text).violations, {
      'lib/a.dart': { foo_extended: [3, 1], keep: [2] },
      'lib/b.dart': { foo_extended: [1, 5] },
    });
    assert.ok(r.text.endsWith('\n'));
    assert.strictEqual(rewriteBaseline(r.text, map).text, r.text);
  });
  it('leaves invalid JSON alone', () => {
    assert.strictEqual(rewriteBaseline('{nope', map).text, '{nope');
  });
});
