/**
 * Tests for the supplementary-counts module that powers the Findings Dashboard
 * gap-closing pills (#224). The module subtracts saropa's known violation
 * count from the live VS Code diagnostic stream to derive "other analyzer
 * findings" and "analyzer TODOs" — display-only counts that never feed health
 * score or filtering.
 *
 * Coverage philosophy: this module is a pure counter. The risky parts are
 * (a) the source-string premise (saropa rules surface as source "dart"), (b)
 * handling all four shapes of `Diagnostic.code`, (c) excluding non-.dart
 * files, and (d) the clamp-to-zero that catches premise violations gracefully.
 * Each test exercises one of those concerns plus a realistic mixed scenario
 * matching the numbers from the original issue.
 */

import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { countSupplementaryDiagnostics } from '../supplementaryDiagnostics';

// Minimal Uri shim that matches the subset of `vscode.Uri` actually read by
// the module (only `.path`). Avoids dragging in vscode-mock's full Uri shape.
function uri(path: string): { path: string } {
  return { path };
}

// `Diagnostic` is shaped — we only set the fields the counter reads. `range`
// and `message` are required at the type level but never read, so we set
// dummies. Cast to `any` keeps the test ergonomic without dragging the full
// Diagnostic class in.
function diag(source: string | undefined, code: any): any {
  return { source, code, message: '', range: undefined };
}

// Builds the `getDiagnostics` shape: array of `[Uri, Diagnostic[]]` tuples.
// Using `as any` because we are only matching the structural subset the
// counter reads (uri.path + diagnostic.source + diagnostic.code).
function fakeGet(
  entries: ReadonlyArray<readonly [{ path: string }, ReadonlyArray<any>]>,
): () => any {
  return () => entries as any;
}

describe('countSupplementaryDiagnostics', () => {
  it('returns zeros and hasDartFiles=false when no diagnostics exist', () => {
    // Cold-start case: brand-new workspace, nothing analyzed yet.
    const result = countSupplementaryDiagnostics(0, fakeGet([]));
    assert.strictEqual(result.otherAnalyzerCount, 0);
    assert.strictEqual(result.analyzerTodosCount, 0);
    assert.strictEqual(result.hasDartFiles, false);
  });

  it('returns zeros when all diagnostics belong to saropa', () => {
    // Pure saropa workspace — the subtraction exactly cancels and the
    // supplementary line should not render anything.
    const entries = [
      [uri('lib/a.dart'), [
        diag('dart', 'avoid_print'),
        diag('dart', 'avoid_dynamic_calls'),
      ]],
    ] as const;
    const result = countSupplementaryDiagnostics(2, fakeGet(entries));
    assert.strictEqual(result.otherAnalyzerCount, 0);
    assert.strictEqual(result.analyzerTodosCount, 0);
    assert.strictEqual(result.hasDartFiles, true);
  });

  it('excludes non-dart files entirely', () => {
    // YAML/MD diagnostics from analyzer-side tooling must not be attributed
    // to the .dart bucket — they would inflate "other analyzer findings".
    const entries = [
      [uri('lib/a.dart'), [diag('dart', 'unused_import')]],
      [uri('pubspec.yaml'), [diag('dart', 'asset_does_not_exist')]],
      [uri('README.md'), [diag('dart', 'something')]],
    ] as const;
    const result = countSupplementaryDiagnostics(0, fakeGet(entries));
    assert.strictEqual(result.otherAnalyzerCount, 1);
    assert.strictEqual(result.analyzerTodosCount, 0);
  });

  it('excludes diagnostics from non-dart sources (Package Vibrancy, Drift)', () => {
    // Other saropa extensions register diagnostics with their own source
    // strings — those must NOT be counted in the analyzer bucket, otherwise
    // the dashboard would double-count them against itself.
    const entries = [
      [uri('lib/a.dart'), [
        diag('dart', 'unused_import'),
        diag('Package Vibrancy', 'sdk-constraint'),
        diag('Drift Advisor', 'anomaly'),
      ]],
    ] as const;
    const result = countSupplementaryDiagnostics(0, fakeGet(entries));
    assert.strictEqual(result.otherAnalyzerCount, 1);
  });

  it('separates code="todo" diagnostics into their own bucket', () => {
    // Analyzer-side TODO lint is reported as code: "todo", source: "dart".
    // It must land in `analyzerTodosCount`, not be double-counted in the
    // non-TODO bucket.
    const entries = [
      [uri('lib/a.dart'), [
        diag('dart', 'todo'),
        diag('dart', 'todo'),
        diag('dart', 'unused_import'),
      ]],
    ] as const;
    const result = countSupplementaryDiagnostics(0, fakeGet(entries));
    assert.strictEqual(result.analyzerTodosCount, 2);
    assert.strictEqual(result.otherAnalyzerCount, 1);
  });

  it('handles the link-target object shape of Diagnostic.code', () => {
    // VS Code allows `code: { value: "todo", target: Uri }` so plugins can
    // attach a help link. The TODO detection must match the wrapped form.
    const entries = [
      [uri('lib/a.dart'), [
        diag('dart', { value: 'todo', target: { path: 'http://x' } }),
        diag('dart', { value: 'unused_import', target: { path: 'http://x' } }),
      ]],
    ] as const;
    const result = countSupplementaryDiagnostics(0, fakeGet(entries));
    assert.strictEqual(result.analyzerTodosCount, 1);
    assert.strictEqual(result.otherAnalyzerCount, 1);
  });

  it('treats numeric and undefined code as non-TODO', () => {
    // Numeric codes occur in some analyzer-plugin shapes; undefined is the
    // default for ad-hoc Diagnostic construction. Neither is a TODO.
    const entries = [
      [uri('lib/a.dart'), [
        diag('dart', 42),
        diag('dart', undefined),
      ]],
    ] as const;
    const result = countSupplementaryDiagnostics(0, fakeGet(entries));
    assert.strictEqual(result.analyzerTodosCount, 0);
    assert.strictEqual(result.otherAnalyzerCount, 2);
  });

  it('clamps otherAnalyzerCount to 0 when saropa count exceeds raw count', () => {
    // Race condition: violations.json was just written (high saropa count)
    // but VS Code has not re-emitted diagnostics yet (stale low count). The
    // arithmetic would go negative; clamp prevents a nonsense "-5 other
    // analyzer findings" pill.
    const entries = [
      [uri('lib/a.dart'), [diag('dart', 'unused_import')]],
    ] as const;
    const result = countSupplementaryDiagnostics(500, fakeGet(entries));
    assert.strictEqual(result.otherAnalyzerCount, 0);
  });

  it('matches the issue #224 scenario: 354 saropa + 38 other + 20 todos = 412 total', () => {
    // Realistic reproduction of the original bug report. Build 354 saropa +
    // 38 other + 20 todos as raw dart diagnostics; module must report 38/20
    // for the supplementary buckets so dashboard pill + saropa total agrees
    // with the user's Problems-panel count of 412.
    const saropaDiags = Array.from({ length: 354 }, () => diag('dart', 'saropa_rule_x'));
    const otherDiags = Array.from({ length: 38 }, () => diag('dart', 'unused_import'));
    const todoDiags = Array.from({ length: 20 }, () => diag('dart', 'todo'));
    const entries = [
      [uri('lib/a.dart'), [...saropaDiags, ...otherDiags, ...todoDiags]],
    ] as const;
    const result = countSupplementaryDiagnostics(354, fakeGet(entries));
    assert.strictEqual(result.otherAnalyzerCount, 38);
    assert.strictEqual(result.analyzerTodosCount, 20);
    // Reconciliation arithmetic the user would do manually:
    assert.strictEqual(
      354 + result.otherAnalyzerCount + result.analyzerTodosCount,
      412,
    );
  });

  it('sets hasDartFiles=true when at least one .dart URI has any diagnostic', () => {
    // Drives the scanner-promo pill: only suggest enabling the file-system
    // TODO/HACK scanner if there is actually Dart code in the workspace.
    const entries = [
      [uri('lib/a.dart'), []],
    ] as const;
    const result = countSupplementaryDiagnostics(0, fakeGet(entries));
    assert.strictEqual(result.hasDartFiles, true);
  });
});
