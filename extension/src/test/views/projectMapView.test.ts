/**
 * Unit tests for `extractProjectMapTotals` (`projectMapView.ts`, WP5 —
 * `plans/PLAN_ext_ui_dart_deferred.md`).
 *
 * This repo has a documented history of a parser that silently returned `{}`
 * for years because only its null/empty branches were tested (see
 * `feedback_positive_parser_tests` in project memory) — so this file leads
 * with a POSITIVE case asserting real values flow through, not just that the
 * function doesn't throw on bad input. The fixture below is copied from the
 * exact shape `health_html_reporter.dart:30-39` emits (`buildHealthHtml`'s
 * `data` map, single-line via `jsonEncode` — no `JsonEncoder.withIndent`),
 * wrapped the same way `health_html_template.dart` wraps it: `const DATA =
 * {...};` as its own line, immediately followed by `const dark = ...;`.
 *
 * `projectMapView.ts` transitively requires the real 'vscode' module at
 * runtime (it calls `vscode.window.createWebviewPanel` etc.), so the mock
 * must be registered before importing it — same requirement
 * `projectMapReports.test.ts` documents for the same reason.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { extractProjectMapTotals } from '../../views/projectMapView';

/** Wraps a raw `DATA` object literal string the same way the real report's `<script>` block does. */
function fakeScriptHtml(dataLiteral: string): string {
  return `<script>
const DATA = ${dataLiteral};
const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
const fg = dark ? "#e2e8f0" : "#0f172a";
</script>`;
}

/**
 * The exact object shape `buildHealthHtml` builds (`health_html_reporter.dart:30-66`):
 * `projectPath`, `generatedAt`, `totals` (the 5 fields this parser reads),
 * plus `folderTree`/`scatter`/`hotspots`/`featureGravity` — included so this
 * fixture is realistic, not a stripped-down shape this parser happens to like.
 */
function realisticDataLiteral(totals: {
  fileCount: number;
  loc: number;
  bytes: number;
  deadFiles: number;
  hotspots: number;
}): string {
  return JSON.stringify({
    projectPath: '/proj',
    generatedAt: '2026-09-05T00:00:00.000Z',
    totals,
    folderTree: { name: 'root', children: [], loc: totals.loc, bytes: totals.bytes },
    scatter: [{ name: 'lib/foo.dart', churn: 3, cognitive: 12, loc: 80 }],
    hotspots: [
      {
        path: 'lib/foo.dart',
        fire: 2,
        loc: 80,
        cognitive: 12,
        mi: 65.5,
        churn: 3,
        reasons: ['high churn'],
      },
    ],
    featureGravity: [],
  });
}

describe('extractProjectMapTotals', () => {
  it('reads real fileCount/loc/bytes/deadFiles/hotspots values out of a realistic report script', () => {
    // Deliberately large numbers (not 1s or small round numbers) so a parser
    // that accidentally truncates, off-by-ones, or reads the wrong field
    // would fail this assertion instead of coincidentally matching.
    const totals = extractProjectMapTotals(
      fakeScriptHtml(
        realisticDataLiteral({
          fileCount: 1900,
          loc: 523841,
          bytes: 18874368,
          deadFiles: 0,
          hotspots: 42,
        }),
      ),
    );
    assert.ok(totals, 'expected totals to be extracted, got undefined');
    assert.strictEqual(totals!.fileCount, 1900);
    assert.strictEqual(totals!.loc, 523841);
    assert.strictEqual(totals!.bytes, 18874368);
    // Zero is the truthiness-bug canary: `if (n)` style guards would treat 0
    // as "missing" and either drop the field or fall through to undefined.
    assert.strictEqual(totals!.deadFiles, 0);
    assert.strictEqual(totals!.hotspots, 42);
  });

  it('returns undefined (never throws) when the script has no "const DATA = " line at all', () => {
    const html = `<script>\nconst somethingElse = 1;\n</script>`;
    assert.strictEqual(extractProjectMapTotals(html), undefined);
  });

  it('returns undefined (never throws) on malformed JSON after "const DATA = "', () => {
    const html = fakeScriptHtml('{not valid json');
    assert.strictEqual(extractProjectMapTotals(html), undefined);
  });

  it('returns undefined when totals is present but missing a required field', () => {
    const literal = JSON.stringify({
      totals: { fileCount: 10, loc: 100, bytes: 200, deadFiles: 0 /* hotspots missing */ },
    });
    assert.strictEqual(extractProjectMapTotals(fakeScriptHtml(literal)), undefined);
  });

  it('returns undefined when a totals field has the wrong type (string instead of number)', () => {
    const literal = JSON.stringify({
      totals: { fileCount: '10', loc: 100, bytes: 200, deadFiles: 0, hotspots: 1 },
    });
    assert.strictEqual(extractProjectMapTotals(fakeScriptHtml(literal)), undefined);
  });

  it('returns undefined when DATA has no totals key at all', () => {
    const literal = JSON.stringify({ projectPath: '/proj' });
    assert.strictEqual(extractProjectMapTotals(fakeScriptHtml(literal)), undefined);
  });
});
