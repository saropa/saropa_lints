/**
 * Unit tests for [mergeCodeHealthSuppression]. The merge function is pure and
 * lives in its own module so the rules — bare-directive idempotency, comma-
 * list extension, mixed-rule fallback, and top-of-file insertion — can be
 * verified without spinning up VS Code's file APIs. The rules here mirror
 * exactly what the Dart-side parser in `lib/src/cli/project_vibrancy.dart`
 * accepts; if you change one, change the other.
 */
import * as assert from 'node:assert';

import { mergeCodeHealthSuppression } from '../../views/codeHealthSuppression';

describe('mergeCodeHealthSuppression', () => {
  it('inserts a fresh directive at top of file when none exists', () => {
    const before = 'int foo() => 1;\n';
    const r = mergeCodeHealthSuppression(before, 'complex');
    assert.strictEqual(r.noChange, false);
    assert.ok(r.content.startsWith('// ignore_for_file: code_health:complex\n'));
    assert.ok(r.content.includes('int foo() => 1;'));
  });

  it('extends an existing code_health flag list (sorted, dedup)', () => {
    const before = '// ignore_for_file: code_health:undocumented\nint foo() => 1;\n';
    const r = mergeCodeHealthSuppression(before, 'complex');
    assert.strictEqual(r.noChange, false);
    // Sorted: complex,undocumented
    assert.ok(r.content.startsWith('// ignore_for_file: code_health:complex,undocumented\n'));
  });

  it('is idempotent when the flag is already in the list', () => {
    const before = '// ignore_for_file: code_health:complex,undocumented\nint foo() => 1;\n';
    const r = mergeCodeHealthSuppression(before, 'complex');
    assert.strictEqual(r.noChange, true);
    assert.strictEqual(r.content, before);
  });

  it('is idempotent when a bare directive already covers everything', () => {
    const before = '// ignore_for_file: code_health\nint foo() => 1;\n';
    const r = mergeCodeHealthSuppression(before, 'complex');
    assert.strictEqual(r.noChange, true);
    assert.strictEqual(r.content, before);
  });

  it('appends a new directive line when the existing one carries OTHER rules only', () => {
    // The existing line has `avoid_print` but no `code_health` — don't risk
    // ambiguity by squeezing `code_health:complex` into the same comma list;
    // add a fresh line below.
    const before = '// ignore_for_file: avoid_print\nint foo() => 1;\n';
    const r = mergeCodeHealthSuppression(before, 'complex');
    assert.strictEqual(r.noChange, false);
    const lines = r.content.split('\n');
    assert.strictEqual(lines[0], '// ignore_for_file: avoid_print');
    assert.strictEqual(lines[1], '// ignore_for_file: code_health:complex');
  });

  it('extends mixed-list `avoid_print, code_health:complex` rather than appending', () => {
    const before = '// ignore_for_file: avoid_print, code_health:complex\nint foo() => 1;\n';
    const r = mergeCodeHealthSuppression(before, 'undocumented');
    assert.strictEqual(r.noChange, false);
    // The code_health flag list grows in place; the other rules in the comma
    // list stay where they were.
    assert.ok(r.content.startsWith(
      '// ignore_for_file: avoid_print, code_health:complex,undocumented\n',
    ));
  });

  it('rejects empty/whitespace flag names without altering the file', () => {
    const before = 'int foo() => 1;\n';
    const r = mergeCodeHealthSuppression(before, '   ');
    assert.strictEqual(r.noChange, true);
    assert.strictEqual(r.content, before);
  });

  it('honors a token-boundary check on the left of `code_health`', () => {
    // `not_code_health` (hypothetical hostile rule name) must NOT be matched
    // as a `code_health` directive. The line should fall through to the
    // "OTHER rules only" branch and append a new directive below.
    const before = '// ignore_for_file: not_code_health\nint foo() => 1;\n';
    const r = mergeCodeHealthSuppression(before, 'complex');
    assert.strictEqual(r.noChange, false);
    const lines = r.content.split('\n');
    assert.strictEqual(lines[0], '// ignore_for_file: not_code_health');
    assert.strictEqual(lines[1], '// ignore_for_file: code_health:complex');
  });
});
