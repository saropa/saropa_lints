/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks).
 */

// Must load the vscode-module shim BEFORE importing setup.ts, which imports
// 'vscode' at module scope. Without this, the require resolver can't find
// 'vscode' outside the VS Code host and the whole test suite fails to load.
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { analysisIssuesActions, formatAnalysisIssuesMessage } from '../setup';

// Regression coverage for bugs/infra_run_analysis_popup_dumps_progress_stderr.md.
// The earlier popup sliced dart analyze's stderr progress bar into the user's
// view, which carried no count and no next step. These tests pin the new
// contract: message = count + plural-correct noun + optional scope suffix,
// with a non-count fallback when violations.json is unreadable (total === 0).
describe('formatAnalysisIssuesMessage', () => {
  it('pluralizes when total > 1', () => {
    assert.strictEqual(
      formatAnalysisIssuesMessage(5234),
      'Saropa Lints: 5,234 issues found.',
    );
  });

  it('uses singular noun when total === 1', () => {
    assert.strictEqual(
      formatAnalysisIssuesMessage(1),
      'Saropa Lints: 1 issue found.',
    );
  });

  it('formats thousands separators via toLocaleString', () => {
    // 5,234 is far more legible than 5234 in a warning popup — confirm the
    // formatter isn't stripped by a future refactor.
    const msg = formatAnalysisIssuesMessage(5234);
    assert.ok(msg.includes('5,234'), `expected thousands separator in: ${msg}`);
  });

  it('appends scope label when provided', () => {
    assert.strictEqual(
      formatAnalysisIssuesMessage(42, 'open editors only'),
      'Saropa Lints: 42 issues found (open editors only).',
    );
  });

  it('omits scope label (no stray space / empty parens) when scope is undefined', () => {
    const msg = formatAnalysisIssuesMessage(42);
    assert.ok(!msg.includes('()'), `unexpected empty parens: ${msg}`);
    assert.ok(!msg.includes('  '), `unexpected double-space: ${msg}`);
    assert.strictEqual(msg, 'Saropa Lints: 42 issues found.');
  });

  it('falls back to "non-zero exit" copy when total === 0', () => {
    // violations.json missing or unreadable → we can't promise a count, so
    // redirect users to Output instead of lying with "0 issues found".
    assert.strictEqual(
      formatAnalysisIssuesMessage(0),
      'Saropa Lints analysis finished with a non-zero exit. See Output for details.',
    );
  });

  it('includes scope label in the zero-count fallback', () => {
    assert.strictEqual(
      formatAnalysisIssuesMessage(0, 'open editors only'),
      'Saropa Lints analysis finished with a non-zero exit (open editors only). See Output for details.',
    );
  });

  // Pins the "which plugin version produced these diagnostics?" answer into
  // the popup so the user doesn't have to open a report file to find out.
  // Previously the only place the version appeared was the Dart-plugin
  // report header's `Version:` line, and THAT was broken to `unknown`.
  it('prepends saropa_lints version when supplied', () => {
    assert.strictEqual(
      formatAnalysisIssuesMessage(42, undefined, '12.4.2'),
      'Saropa Lints v12.4.2: 42 issues found.',
    );
  });

  it('includes saropa_lints version in the zero-count fallback too', () => {
    assert.strictEqual(
      formatAnalysisIssuesMessage(0, undefined, '12.4.2'),
      'Saropa Lints v12.4.2 analysis finished with a non-zero exit. See Output for details.',
    );
  });

  it('combines version + scope label', () => {
    assert.strictEqual(
      formatAnalysisIssuesMessage(5, 'open editors only', '12.4.2'),
      'Saropa Lints v12.4.2: 5 issues found (open editors only).',
    );
  });

  it('omits the version label when version is undefined (no "v" ghost)', () => {
    // Covers the unresolved-lock path: pubspec.lock missing, unreadable, or
    // doesn't declare saropa_lints. We must NOT emit `v undefined` or a bare
    // `v` — silent omission is the intended failure mode.
    const msg = formatAnalysisIssuesMessage(42, undefined, undefined);
    assert.ok(!msg.includes(' v '), `unexpected bare "v" token in: ${msg}`);
    assert.ok(!msg.includes('vundefined'), `undefined leaked into: ${msg}`);
    assert.strictEqual(msg, 'Saropa Lints: 42 issues found.');
  });
});

// Gating matrix for the post-analysis popup's action buttons. The popup
// previously offered "View Violations" / "Copy Report" / "Open Report"
// unconditionally; on a run that exited non-zero but produced no saropa_lints
// findings (no violations.json content, no report log) three of the four
// buttons were inert and read as broken. analysisIssuesActions makes each
// button appear only when its target artifact exists.
describe('analysisIssuesActions', () => {
  it('offers all four actions when there are violations and a report', () => {
    assert.deepStrictEqual(analysisIssuesActions(7, true), [
      'View Violations',
      'Copy Report',
      'Open Report',
      'Show Output',
    ]);
  });

  it('drops Copy/Open Report when the report log is absent', () => {
    // The dashboard can still render violations, but there is no
    // *_saropa_lint_report.log to copy or open — so those two buttons must
    // not appear and flash a dead "no report found" toast.
    assert.deepStrictEqual(analysisIssuesActions(7, false), [
      'View Violations',
      'Show Output',
    ]);
  });

  it('drops View Violations when nothing is renderable but a report exists', () => {
    assert.deepStrictEqual(analysisIssuesActions(0, true), [
      'Copy Report',
      'Open Report',
      'Show Output',
    ]);
  });

  it('shows only Show Output for a non-zero exit with no findings and no report', () => {
    // The exact false-popup case: dart analyze exited non-zero (e.g. a
    // compile error) but the plugin produced neither violations nor a report.
    // Only the always-valid Output action survives.
    assert.deepStrictEqual(analysisIssuesActions(0, false), ['Show Output']);
  });

  it('always includes Show Output', () => {
    for (const renderable of [0, 1, 999]) {
      for (const hasReport of [true, false]) {
        assert.ok(
          analysisIssuesActions(renderable, hasReport).includes('Show Output'),
          `Show Output missing for renderable=${renderable} hasReport=${hasReport}`,
        );
      }
    }
  });
});
