/**
 * Tests for the live-diagnostics dashboard model (#1a).
 *
 * The Findings Dashboard now sources findings from
 * `vscode.languages.getDiagnostics()` instead of the batch `violations.json`
 * export, so it stays structurally in sync with the Problems panel — the two
 * read the same diagnostic array and cannot diverge into "0 findings / grade A"
 * while Problems shows dozens.
 *
 * These tests pin the `Diagnostic -> Violation` mapping: the model's violation
 * count equals the live diagnostic count (the anti-divergence guarantee),
 * severities collapse to the 3-bucket vocabulary, file paths are
 * root-relative/forward-slashed (so click-to-source navigation resolves the
 * same way `saropaLints.openFileAndFocusIssues` does), the `[rule]` message
 * prefix is stripped, non-.dart diagnostics are excluded, and an empty stream
 * yields a valid zeroed model rather than null.
 */

import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as vscode from 'vscode';
import { applyRuleCatalog, buildViolationsDataFromDiagnostics } from '../liveDiagnosticsModel';
import type { RuleMetadataData } from '../violationsReader';

const ROOT = '/proj';

// Structural Uri shim — the module reads only `.fsPath`.
function uri(fsPath: string): unknown {
  return { fsPath };
}

// Structural Diagnostic shim — the module reads severity/range/message/code/
// source. Defaults keep call sites terse where a field is irrelevant.
function diag(opts: {
  severity?: vscode.DiagnosticSeverity;
  line?: number;
  message?: string;
  code?: unknown;
  source?: string;
}): unknown {
  return {
    severity: opts.severity ?? vscode.DiagnosticSeverity.Warning,
    range: { start: { line: opts.line ?? 0, character: 0 } },
    message: opts.message ?? '',
    code: opts.code,
    source: opts.source ?? 'dart',
  };
}

// Builds the `getDiagnostics` shape: array of `[Uri, Diagnostic[]]` tuples.
// `as never` because we match only the structural subset the builder reads.
function fakeGet(
  entries: ReadonlyArray<readonly [unknown, ReadonlyArray<unknown>]>,
): () => never {
  return () => entries as never;
}

describe('buildViolationsDataFromDiagnostics', () => {
  it('produces one violation per live diagnostic (count == Problems)', () => {
    // The anti-divergence guarantee: the model can never show fewer findings
    // than the diagnostic stream the Problems panel reads from.
    const entries = [
      [uri('/proj/lib/a.dart'), [diag({ code: 'avoid_print' }), diag({ code: 'require_dispose' })]],
      [uri('/proj/lib/b.dart'), [diag({ code: 'avoid_print' })]],
    ] as const;
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet(entries));
    assert.strictEqual(data.violations.length, 3);
    assert.strictEqual(data.summary?.totalViolations, 3);
  });

  it('maps DiagnosticSeverity onto the 3-bucket vocabulary', () => {
    const entries = [
      [uri('/proj/lib/a.dart'), [
        diag({ severity: vscode.DiagnosticSeverity.Error, code: 'e' }),
        diag({ severity: vscode.DiagnosticSeverity.Warning, code: 'w' }),
        diag({ severity: vscode.DiagnosticSeverity.Information, code: 'i' }),
        diag({ severity: vscode.DiagnosticSeverity.Hint, code: 'h' }),
      ]],
    ] as const;
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet(entries));
    assert.deepStrictEqual(
      data.violations.map((v) => v.severity),
      ['error', 'warning', 'info', 'info'],
    );
    // Information and Hint both collapse to info.
    assert.strictEqual(data.summary?.bySeverity?.info, 2);
    assert.strictEqual(data.summary?.bySeverity?.error, 1);
  });

  it('emits root-relative, forward-slashed file paths for navigation', () => {
    const entries = [
      [uri('/proj/lib/feature/widget.dart'), [diag({ code: 'x' })]],
    ] as const;
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet(entries));
    assert.strictEqual(data.violations[0].file, 'lib/feature/widget.dart');
  });

  it('1-bases the line number (Diagnostic ranges are 0-based)', () => {
    const entries = [
      [uri('/proj/lib/a.dart'), [diag({ line: 0, code: 'x' }), diag({ line: 41, code: 'y' })]],
    ] as const;
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet(entries));
    assert.strictEqual(data.violations[0].line, 1);
    assert.strictEqual(data.violations[1].line, 42);
  });

  it('extracts the rule from string, object, and missing code', () => {
    const entries = [
      [uri('/proj/lib/a.dart'), [
        diag({ code: 'avoid_print' }),
        diag({ code: { value: 'require_dispose', target: { path: 'http://x' } } }),
        diag({ code: undefined, source: 'dart' }),
      ]],
    ] as const;
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet(entries));
    assert.strictEqual(data.violations[0].rule, 'avoid_print');
    assert.strictEqual(data.violations[1].rule, 'require_dispose');
    // Code-less diagnostic falls back to source so it still groups somewhere.
    assert.strictEqual(data.violations[2].rule, 'dart');
  });

  it('strips the leading [rule] message prefix saropa rules prepend', () => {
    const entries = [
      [uri('/proj/lib/a.dart'), [
        diag({
          code: 'require_catch_logging',
          message: '[require_catch_logging] Catch block swallows the exception.',
        }),
        diag({ code: 'sdk_lint', message: 'Unused import.' }),
      ]],
    ] as const;
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet(entries));
    assert.strictEqual(data.violations[0].message, 'Catch block swallows the exception.');
    // No prefix -> message untouched.
    assert.strictEqual(data.violations[1].message, 'Unused import.');
  });

  it('excludes non-dart files so the holistic view stays Dart-scoped', () => {
    const entries = [
      [uri('/proj/lib/a.dart'), [diag({ code: 'x' })]],
      [uri('/proj/pubspec.yaml'), [diag({ code: 'asset_missing' })]],
      [uri('/proj/README.md'), [diag({ code: 'y' })]],
    ] as const;
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet(entries));
    assert.strictEqual(data.violations.length, 1);
    assert.strictEqual(data.violations[0].file, 'lib/a.dart');
  });

  it('returns a valid zeroed model (not null) when there are no diagnostics', () => {
    // Clean state — the dashboard renders the zeroed A/100 view from this, so
    // there is no "no report yet" wall to fall back to.
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet([]));
    assert.strictEqual(data.violations.length, 0);
    assert.strictEqual(data.summary?.totalViolations, 0);
    assert.ok(data.timestamp);
  });

  it('is holistic — counts every linter, not only saropa rules', () => {
    // Unlike the supplementary counter (which subtracts to isolate non-saropa
    // findings), this includes all sources in one combined view.
    const entries = [
      [uri('/proj/lib/a.dart'), [
        diag({ code: 'avoid_print', source: 'dart' }),
        diag({ code: 'prefer_final', source: 'dart' }),
      ]],
    ] as const;
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet(entries));
    assert.strictEqual(data.violations.length, 2);
  });

  it('passes the configured tier through without reading any file', () => {
    const data = buildViolationsDataFromDiagnostics(ROOT, fakeGet([]), 'professional');
    assert.strictEqual(data.config?.tier, 'professional');
  });
});

describe('applyRuleCatalog', () => {
  // A minimal catalog: one security-hotspot rule, one ordinary bug rule.
  const catalog: Record<string, RuleMetadataData> = {
    avoid_hardcoded_secret: {
      ruleType: 'securityHotspot',
      ruleStatus: 'ready',
      requiresReview: true,
      tags: ['security', 'review-required'],
    },
    avoid_print: { ruleType: 'codeSmell', ruleStatus: 'beta' },
  };

  function modelWith(rules: string[]): ReturnType<typeof buildViolationsDataFromDiagnostics> {
    const entries = [[uri('/proj/lib/a.dart'), rules.map((r) => diag({ code: r }))]] as const;
    return buildViolationsDataFromDiagnostics(ROOT, fakeGet(entries));
  }

  it('attaches per-rule metadata only for rules present in the model', () => {
    const data = applyRuleCatalog(modelWith(['avoid_print']), catalog);
    assert.deepStrictEqual(Object.keys(data.config?.ruleMetadataByRule ?? {}), ['avoid_print']);
    assert.strictEqual(data.config?.ruleMetadataByRule?.avoid_print?.ruleStatus, 'beta');
  });

  it('issue-weights byRuleType and byRuleStatus from the catalog', () => {
    // Two avoid_print (codeSmell/beta) + one hotspot (securityHotspot/ready).
    const data = applyRuleCatalog(
      modelWith(['avoid_print', 'avoid_print', 'avoid_hardcoded_secret']),
      catalog,
    );
    assert.strictEqual(data.summary?.byRuleType?.codeSmell, 2);
    assert.strictEqual(data.summary?.byRuleType?.securityHotspot, 1);
    assert.strictEqual(data.summary?.byRuleStatus?.beta, 2);
    assert.strictEqual(data.summary?.byRuleStatus?.ready, 1);
  });

  it('falls rules missing from the catalog into unspecified/ready', () => {
    const data = applyRuleCatalog(modelWith(['some_unknown_rule']), catalog);
    assert.strictEqual(data.summary?.byRuleType?.unspecified, 1);
    assert.strictEqual(data.summary?.byRuleStatus?.ready, 1);
    // No metadata copied for a rule the catalog does not know.
    assert.strictEqual(data.config?.ruleMetadataByRule?.some_unknown_rule, undefined);
  });

  it('returns the model unchanged when the catalog is empty', () => {
    const model = modelWith(['avoid_print']);
    const data = applyRuleCatalog(model, {});
    assert.strictEqual(data, model);
  });
});
