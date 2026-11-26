/**
 * Tests for the rule-rename rewriter of `saropa_accepted.yaml` and for the
 * workspace scan picking the list up. Positive cases first, so a rewriter
 * that silently changes nothing cannot pass on the no-op cases alone.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { rewriteAcceptedList } from '../../ruleMigration/acceptedListRewriter';
import { buildRenameMap } from '../../ruleMigration/rewriters';
import { scanWorkspace, type ScanDeps } from '../../ruleMigration/scanner';

const renames = buildRenameMap([
  { old: 'foo', new: 'foo_extended', since: '17.0.0' },
  { old: 'gone', new: null, since: '17.0.0' },
]);

const LIST = [
  '# Reviewed findings',
  'version: 1',
  'accepted:',
  '  - rule: foo',
  '    file: "lib/a.dart"',
  '    reason: "kept: tool output # really"',
  '  - file: lib/b.dart',
  '    rule: "foo"  # quoted, comment after',
  '    reason: x',
  '  - rule: gone',
  '    file: lib/c.dart',
  '    reason: y',
  '  - rule: foobar',
  '    file: lib/d.dart',
  '    reason: z',
  '',
].join('\n');

describe('rewriteAcceptedList', () => {
  it('renames rule values in either key order, bare or quoted', () => {
    const r = rewriteAcceptedList(LIST, renames);
    assert.strictEqual(r.hits, 2);
    assert.ok(r.text.includes('  - rule: foo_extended\n'));
    assert.ok(r.text.includes('    rule: "foo_extended"  # quoted, comment after\n'));
    // Reasons, comments and other keys are untouched.
    assert.ok(r.text.includes('    reason: "kept: tool output # really"\n'));
    assert.ok(r.text.startsWith('# Reviewed findings\nversion: 1\naccepted:\n'));
  });

  it('leaves removed rules and longer names that share a prefix', () => {
    const r = rewriteAcceptedList(LIST, renames);
    assert.ok(r.text.includes('  - rule: gone\n'));
    assert.ok(r.text.includes('  - rule: foobar\n'));
  });

  it('is idempotent and keeps CRLF', () => {
    const once = rewriteAcceptedList(LIST, renames).text;
    const twice = rewriteAcceptedList(once, renames);
    assert.strictEqual(twice.hits, 0);
    assert.strictEqual(twice.text, once);
    const crlf = rewriteAcceptedList('accepted:\r\n  - rule: foo\r\n', renames);
    assert.strictEqual(crlf.text, 'accepted:\r\n  - rule: foo_extended\r\n');
  });

  it('returns the input unchanged when nothing matches', () => {
    const text = 'accepted:\n  - rule: other\n';
    assert.deepStrictEqual(rewriteAcceptedList(text, renames), { text, hits: 0, findings: [] });
  });
});

describe('scanWorkspace with an accepted list', () => {
  it('rewrites saropa_accepted.yaml beside the package', async () => {
    const files = new Map<string, string>([['/w/saropa_accepted.yaml', 'accepted:\n  - rule: foo\n']]);
    const deps: ScanDeps = {
      findFiles: async (root, glob) =>
        glob === '**/saropa_accepted.yaml' ? [...files.keys()].filter((f) => f.startsWith(`${root}/`)) : [],
      read: (f) => files.get(f),
    };
    const res = await scanWorkspace(deps, [{ root: '/w', renames }]);
    assert.strictEqual(res.changes.length, 1);
    assert.strictEqual(res.changes[0].after, 'accepted:\n  - rule: foo_extended\n');
  });
});
