/**
 * Tests for the consolidated dashboard model.
 *
 * Pins the rule-grouping + triage rank + grade that the consolidated dashboard
 * renders: 1000 findings must collapse to per-rule groups ranked
 * worst-severity-then-count, the grade must come from the shared severityScore
 * (so it matches the Findings Dashboard gauge), and occurrences must be retained
 * per group with root-relative paths for the lazy expand.
 */

import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as vscode from 'vscode';
import { buildConsolidatedModel } from '../views/consolidated/consolidatedModel';

const ROOT = '/proj';

function uri(fsPath: string): unknown {
  return { fsPath };
}

function diag(opts: {
  severity?: vscode.DiagnosticSeverity;
  line?: number;
  message?: string;
  code?: unknown;
}): unknown {
  return {
    severity: opts.severity ?? vscode.DiagnosticSeverity.Warning,
    range: { start: { line: opts.line ?? 0, character: 0 } },
    message: opts.message ?? '',
    code: opts.code,
    source: 'dart',
  };
}

function fakeGet(
  entries: ReadonlyArray<readonly [unknown, ReadonlyArray<unknown>]>,
): () => never {
  return () => entries as never;
}

describe('buildConsolidatedModel', () => {
  it('groups findings by rule with per-rule counts', () => {
    const entries = [
      [uri('/proj/lib/a.dart'), [diag({ code: 'avoid_print' }), diag({ code: 'avoid_print' }), diag({ code: 'require_dispose' })]],
      [uri('/proj/lib/b.dart'), [diag({ code: 'avoid_print' })]],
    ] as const;
    const m = buildConsolidatedModel(ROOT, fakeGet(entries));
    const byRule = Object.fromEntries(m.groups.map((g) => [g.rule, g.count]));
    assert.strictEqual(byRule['avoid_print'], 3);
    assert.strictEqual(byRule['require_dispose'], 1);
    assert.strictEqual(m.totals.total, 4);
  });

  it('ranks worst-severity first, then by count', () => {
    const entries = [
      [uri('/proj/lib/a.dart'), [
        diag({ severity: vscode.DiagnosticSeverity.Information, code: 'info_rule' }),
        diag({ severity: vscode.DiagnosticSeverity.Information, code: 'info_rule' }),
        diag({ severity: vscode.DiagnosticSeverity.Information, code: 'info_rule' }),
        diag({ severity: vscode.DiagnosticSeverity.Error, code: 'err_rule' }),
        diag({ severity: vscode.DiagnosticSeverity.Warning, code: 'warn_rule' }),
        diag({ severity: vscode.DiagnosticSeverity.Warning, code: 'warn_rule' }),
      ]],
    ] as const;
    const m = buildConsolidatedModel(ROOT, fakeGet(entries));
    // Error group ranks first despite info_rule having the highest count.
    assert.deepStrictEqual(m.groups.map((g) => g.rule), ['err_rule', 'warn_rule', 'info_rule']);
    assert.strictEqual(m.groups[0].worst, 'error');
  });

  it('computes the holistic grade from the severity mix (shared severityScore)', () => {
    // One error -> penalty 5 -> score 95 -> grade A.
    const oneError = buildConsolidatedModel(
      ROOT,
      fakeGet([[uri('/proj/lib/a.dart'), [diag({ severity: vscode.DiagnosticSeverity.Error, code: 'e' })]]]),
    );
    assert.strictEqual(oneError.score, 95);
    assert.strictEqual(oneError.grade, 'A');

    const clean = buildConsolidatedModel(ROOT, fakeGet([]));
    assert.strictEqual(clean.score, 100);
    assert.strictEqual(clean.grade, 'A');
    assert.strictEqual(clean.groups.length, 0);
  });

  it('counts totals and distinct files', () => {
    const entries = [
      [uri('/proj/lib/a.dart'), [
        diag({ severity: vscode.DiagnosticSeverity.Error, code: 'e' }),
        diag({ severity: vscode.DiagnosticSeverity.Warning, code: 'w' }),
      ]],
      [uri('/proj/lib/b.dart'), [diag({ severity: vscode.DiagnosticSeverity.Information, code: 'i' })]],
    ] as const;
    const m = buildConsolidatedModel(ROOT, fakeGet(entries));
    assert.strictEqual(m.totals.error, 1);
    assert.strictEqual(m.totals.warning, 1);
    assert.strictEqual(m.totals.info, 1);
    assert.strictEqual(m.totals.files, 2);
  });

  it('retains occurrences per group with root-relative paths for lazy load', () => {
    const entries = [
      [uri('/proj/lib/feature/x.dart'), [diag({ line: 41, code: 'r', message: '[r] boom' })]],
    ] as const;
    const m = buildConsolidatedModel(ROOT, fakeGet(entries));
    const g = m.groups.find((x) => x.rule === 'r');
    assert.ok(g);
    assert.strictEqual(g.occurrences.length, 1);
    assert.strictEqual(g.occurrences[0].file, 'lib/feature/x.dart');
    assert.strictEqual(g.occurrences[0].line, 42);
    // The #1a model strips the leading [rule] message prefix.
    assert.strictEqual(g.occurrences[0].message, 'boom');
  });
});
