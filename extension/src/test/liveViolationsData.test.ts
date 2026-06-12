/**
 * Tests for the live-sourced status-bar / Issues-tree read helpers.
 *
 * These wrap the #1a `buildViolationsDataFromDiagnostics` so the status-bar
 * score and the Issues tree grade against the analyzer's current diagnostics
 * instead of the stale `violations.json` export. The tests pin the two behaviors
 * the wrappers add on top of the raw builder: disabled-rule filtering for the
 * visible (score) read, and the boolean has-findings gate for the tree's empty
 * state. Dependencies are injected (getDiagnostics, tier, disabled set) so
 * neither the `vscode` config API nor the filesystem is touched.
 */

import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as vscode from 'vscode';
import {
  readLiveViolations,
  readVisibleLiveViolations,
  hasLiveViolations,
} from '../liveViolationsData';

const ROOT = '/proj';

function uri(fsPath: string): unknown {
  return { fsPath };
}

function diag(code: string, severity?: vscode.DiagnosticSeverity): unknown {
  return {
    severity: severity ?? vscode.DiagnosticSeverity.Warning,
    range: { start: { line: 0, character: 0 } },
    message: `[${code}] something`,
    code,
    source: 'dart',
  };
}

function fakeGet(
  entries: ReadonlyArray<readonly [unknown, ReadonlyArray<unknown>]>,
): () => never {
  return () => entries as never;
}

describe('liveViolationsData', () => {
  const entries = [
    [uri('/proj/lib/a.dart'), [
      diag('avoid_print', vscode.DiagnosticSeverity.Error),
      diag('require_dispose'),
      diag('avoid_print'),
    ]],
  ] as const;

  it('readLiveViolations passes every diagnostic through (holistic, raw)', () => {
    const data = readLiveViolations(ROOT, fakeGet(entries), 'recommended');
    assert.strictEqual(data.violations.length, 3);
    assert.strictEqual(data.config?.tier, 'recommended');
  });

  it('readVisibleLiveViolations removes disabled rules and recomputes the summary', () => {
    // avoid_print is muted -> both its findings drop; the score must not count
    // a rule the user disabled.
    const disabled = new Set<string>(['avoid_print']);
    const data = readVisibleLiveViolations(ROOT, fakeGet(entries), 'recommended', disabled);
    assert.strictEqual(data.violations.length, 1);
    assert.strictEqual(data.violations[0].rule, 'require_dispose');
    assert.strictEqual(data.summary?.totalViolations, 1);
    assert.strictEqual(data.summary?.issuesByRule?.avoid_print, undefined);
  });

  it('readVisibleLiveViolations is a passthrough when nothing is disabled', () => {
    const data = readVisibleLiveViolations(ROOT, fakeGet(entries), 'recommended', new Set());
    assert.strictEqual(data.violations.length, 3);
  });

  it('hasLiveViolations reflects the live count, not a file', () => {
    assert.strictEqual(hasLiveViolations(ROOT, fakeGet(entries)), true);
    // Empty diagnostic stream -> clean project -> false (no stale file to read).
    assert.strictEqual(hasLiveViolations(ROOT, fakeGet([])), false);
  });
});
