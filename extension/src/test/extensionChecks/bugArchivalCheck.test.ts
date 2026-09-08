/**
 * Unit tests for the bug-archival extension-native check: worked example of
 * a check that inspects markdown content and file placement, which a Dart
 * AST rule structurally cannot do. See ISSUE_REPORT_GUIDE.md's "Rule
 * Sources" section for why this exists.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as vscode from 'vscode';

import { isBugReportFile, computeBugArchivalDiagnostic } from '../../extensionChecks/bugArchivalCheck';

/** Fakes `TextDocument.positionAt` for a single-line document. */
function positionAtForSingleLine(): (offset: number) => vscode.Position {
  return (_offset: number) => ({ line: 0, character: 0 }) as vscode.Position;
}

describe('bugArchivalCheck', () => {
  describe('isBugReportFile', () => {
    it('matches a report directly under bugs/', () => {
      assert.strictEqual(isBugReportFile('/repo/bugs/some_bug.md'), true);
    });

    it('excludes the process-documentation guide itself', () => {
      assert.strictEqual(isBugReportFile('/repo/bugs/ISSUE_REPORT_GUIDE.md'), false);
    });

    it('excludes files already archived to plans/history/', () => {
      assert.strictEqual(
        isBugReportFile('/repo/plans/history/2026.09/2026.09.07/some_bug.md'),
        false,
      );
    });

    it('normalizes backslashes for Windows paths', () => {
      assert.strictEqual(isBugReportFile('C:\\repo\\bugs\\some_bug.md'), true);
    });
  });

  describe('computeBugArchivalDiagnostic', () => {
    it('returns null for an open-status report', () => {
      const diag = computeBugArchivalDiagnostic('**Status: Open**\n', positionAtForSingleLine());
      assert.strictEqual(diag, null);
    });

    it('returns null when there is no Status line at all', () => {
      const diag = computeBugArchivalDiagnostic('# Just a title\n', positionAtForSingleLine());
      assert.strictEqual(diag, null);
    });

    it('flags a Fixed report for archival', () => {
      const diag = computeBugArchivalDiagnostic('**Status: Fixed**\n', positionAtForSingleLine());
      assert.ok(diag, 'expected a diagnostic for a Fixed report');
      assert.strictEqual(diag?.source, 'Saropa Lints');
    });

    it('flags a Fixed report using the "**Status:** Fixed" bold-label style', () => {
      const diag = computeBugArchivalDiagnostic('**Status:** Fixed\n', positionAtForSingleLine());
      assert.ok(diag, 'expected a diagnostic regardless of which bold style wraps the field');
    });

    it('flags a Closed report for archival', () => {
      const diag = computeBugArchivalDiagnostic('Status: Closed\n', positionAtForSingleLine());
      assert.ok(diag, 'expected a diagnostic for a Closed report');
    });

    it('flags a Declined proposal for archival', () => {
      const diag = computeBugArchivalDiagnostic('**Status: Declined**\n', positionAtForSingleLine());
      assert.ok(diag, 'expected a diagnostic for a Declined proposal');
    });

    it('does not flag Investigating (an in-progress bug status)', () => {
      const diag = computeBugArchivalDiagnostic('**Status: Investigating**\n', positionAtForSingleLine());
      assert.strictEqual(diag, null);
    });
  });
});
