// Must load the vscode-module shim BEFORE importing setup.ts, which imports
// 'vscode' at module scope. Without this, the require resolver can't find
// 'vscode' outside the VS Code host and the whole test suite fails to load.
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { formatAnalysisIssuesMessage } from '../setup';

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
});
