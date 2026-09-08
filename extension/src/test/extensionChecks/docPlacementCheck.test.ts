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
  DocPlacementCodeActionProvider,
} from '../../extensionChecks/docPlacementCheck';

const ARCHIVE_GLOB = '**/plans/history/**/*.md';
const OPEN_SIGNALS = [
  String.raw`^\*{0,2}Status:\*{0,2}\s*\*{0,2}Open\*{0,2}\s*$`,
  String.raw`^\*{0,2}Severity:\*{0,2}\s*\*{0,2}(Critical|High|Major)\*{0,2}\s*$`,
  String.raw`\|\s*(Critical|High|Major)\s*\|`,
  String.raw`^#{1,6}\s*(Recommended [Nn]ext [Ss]teps|Work [Ss]till to [Dd]o|TODO|Open [Ii]tems)\s*$`,
];
const CLOSED_SIGNALS = [String.raw`^\*{0,2}Status:\*{0,2}\s*\*{0,2}(Fixed|Closed|Done)\*{0,2}\s*$`];

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

    it('matches a bare "*.md" glob only against a path with no "/" at all', () => {
      // No leading '**', so '*' cannot cross a '/' — this only matches a
      // path VS Code would report as just "report.md" with no directory,
      // never a real absolute/workspace-relative path (see the JSDoc note
      // on globToRegExp about there being no implicit '**' prefix).
      assert.strictEqual(matchesArchiveGlob('report.md', '*.md'), true);
      assert.strictEqual(matchesArchiveGlob('/repo/report.md', '*.md'), false);
    });

    it('matches a glob with no wildcards only as an exact full-path literal', () => {
      assert.strictEqual(matchesArchiveGlob('notes.md', 'notes.md'), true);
      assert.strictEqual(matchesArchiveGlob('/repo/notes.md', 'notes.md'), false);
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

    it('flags a bold-value severity field ("Severity: **Critical**")', () => {
      const text = '# Report Title\n\nSeverity: **Critical**\n\n## Open items\n1. Fix it.\n';
      const diag = computeDocPlacementDiagnostic(text, OPEN_SIGNALS, CLOSED_SIGNALS, 'bugs/');
      assert.ok(diag, 'expected a diagnostic for a bold-value Severity field');
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

    it('sets a diagnostic code so the quick fix can scope to this check only', () => {
      const text = 'Status: Open\n';
      const diag = computeDocPlacementDiagnostic(text, OPEN_SIGNALS, CLOSED_SIGNALS, 'bugs/');
      assert.strictEqual(diag?.code, 'docPlacement');
    });
  });

  describe('DocPlacementCodeActionProvider', () => {
    const provider = new DocPlacementCodeActionProvider();
    const fakeDocument = { uri: { fsPath: '/repo/plans/history/report.md' } } as any;
    const fakeRange = {} as any;

    it('offers no action when no diagnostic in context has this check\'s code', () => {
      const context = { diagnostics: [{ code: 'someOtherCheck' }] } as any;
      const actions = provider.provideCodeActions(fakeDocument, fakeRange, context);
      assert.strictEqual(actions.length, 0);
    });

    it('offers a "move" quick fix scoped to this check\'s diagnostics only', () => {
      const ownDiag = { code: 'docPlacement' };
      const otherDiag = { code: 'someOtherCheck' };
      const context = { diagnostics: [ownDiag, otherDiag] } as any;
      const actions = provider.provideCodeActions(fakeDocument, fakeRange, context);
      assert.strictEqual(actions.length, 1);
      assert.deepStrictEqual(actions[0].diagnostics, [ownDiag]);
      assert.strictEqual(actions[0].command?.command, 'saropaLints.docPlacement.moveToOpenIssues');
    });
  });
});
