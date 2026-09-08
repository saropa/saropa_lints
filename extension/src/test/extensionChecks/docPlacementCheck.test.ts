/**
 * Unit tests for the doc-placement extension-native check — the mirror
 * image of bugArchivalCheck.test.ts. Covers the three worked examples from
 * bugs/proposal_infra_doc_history_vs_bugs_placement.md plus the glob
 * matcher and edge cases it documents.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import {
  globToRegExp,
  matchesArchiveGlob,
  computeDocPlacementDiagnostic,
} from '../../extensionChecks/docPlacementCheck';

const ARCHIVE_GLOB = '**/plans/history/**/*.md';
const OPEN_SIGNALS = [
  String.raw`^\*{0,2}Status:\*{0,2}\s*Open\*{0,2}\s*$`,
  String.raw`^\*{0,2}Severity:\*{0,2}\s*(Critical|High|Major)\*{0,2}\s*$`,
  String.raw`\|\s*(Critical|High|Major)\s*\|`,
  String.raw`^#{1,6}\s*(Recommended [Nn]ext [Ss]teps|Work [Ss]till to [Dd]o|TODO|Open [Ii]tems)\s*$`,
];
const CLOSED_SIGNALS = [String.raw`^\*{0,2}Status:\*{0,2}\s*(Fixed|Closed|Done)\*{0,2}\s*$`];

describe('docPlacementCheck', () => {
  describe('globToRegExp / matchesArchiveGlob', () => {
    it('matches a file nested under the archive directory', () => {
      assert.strictEqual(
        matchesArchiveGlob('/repo/plans/history/2026.09/2026.09.08/report.md', ARCHIVE_GLOB),
        true,
      );
    });

    it('does not match a file outside the archive directory', () => {
      assert.strictEqual(matchesArchiveGlob('/repo/bugs/report.md', ARCHIVE_GLOB), false);
    });

    it('normalizes backslashes for Windows paths', () => {
      assert.strictEqual(
        matchesArchiveGlob('C:\\repo\\plans\\history\\2026.09\\report.md', ARCHIVE_GLOB),
        true,
      );
    });

    it('does not match a non-markdown file even under the archive directory', () => {
      assert.strictEqual(matchesArchiveGlob('/repo/plans/history/report.txt', ARCHIVE_GLOB), false);
    });

    it('treats "**" as matching zero segments too', () => {
      // '**/plans/history/**/*.md' with nothing between 'history/' and the filename.
      assert.strictEqual(matchesArchiveGlob('/repo/plans/history/report.md', ARCHIVE_GLOB), true);
    });
  });

  describe('computeDocPlacementDiagnostic', () => {
    it('flags open work filed in the archive path (should-flag example)', () => {
      const text = '# Report Title\n\nSeverity: Critical\n\n## Recommended next steps\n1. Fix the thing.\n';
      const diag = computeDocPlacementDiagnostic(text, OPEN_SIGNALS, CLOSED_SIGNALS, 'bugs/');
      assert.ok(diag, 'expected a diagnostic for open work in the archive path');
      assert.strictEqual(diag?.source, 'Saropa Lints');
    });

    it('does not flag when a closed signal overrides the stale open marker', () => {
      const text = 'Status: Fixed\n\nNo open findings remain — all items resolved and verified.\n';
      const diag = computeDocPlacementDiagnostic(text, OPEN_SIGNALS, CLOSED_SIGNALS, 'bugs/');
      assert.strictEqual(diag, null);
    });

    it('recognizes the "**Status:** Fixed" bold-label style used by this repo\'s own archived docs', () => {
      const text = '**Status:** Fixed\n\n## Recommended next steps\n1. Already done, left for history.\n';
      const diag = computeDocPlacementDiagnostic(text, OPEN_SIGNALS, CLOSED_SIGNALS, 'bugs/');
      assert.strictEqual(diag, null);
    });

    it('does not flag when no open signal is present at all', () => {
      const text = '# Just a title\n\nSome unrelated prose.\n';
      const diag = computeDocPlacementDiagnostic(text, OPEN_SIGNALS, CLOSED_SIGNALS, 'bugs/');
      assert.strictEqual(diag, null);
    });

    it('does not fire on a bare-word mention of a severity term in prose (edge case 2)', () => {
      const text = '# Report Title\n\nThis used to be a Critical finding, now resolved.\n';
      const diag = computeDocPlacementDiagnostic(text, OPEN_SIGNALS, CLOSED_SIGNALS, 'bugs/');
      assert.strictEqual(diag, null);
    });

    it('flags a severity table cell', () => {
      const text = '# Report\n\n| Finding | Severity |\n| --- | --- |\n| X | Critical |\n';
      const diag = computeDocPlacementDiagnostic(text, OPEN_SIGNALS, CLOSED_SIGNALS, 'bugs/');
      assert.ok(diag, 'expected a diagnostic for a Critical severity table cell');
    });

    it('skips an invalid user-supplied regex rather than throwing', () => {
      const text = '# Report\n\nStatus: Open\n';
      const diag = computeDocPlacementDiagnostic(text, ['(unterminated', ...OPEN_SIGNALS], CLOSED_SIGNALS, 'bugs/');
      assert.ok(diag, 'expected the valid patterns to still be evaluated');
    });
  });
});
