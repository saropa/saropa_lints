/**
 * Config Dashboard (Manage Rule Packs) suppressions strip, rendered from export data.
 *
 * Empty/zero variants collapse to a single muted line with no CTA per UX_UI_GUIDELINES §8.16
 * — the strip only earns a bordered band and an *Open Findings* CTA when there is something
 * to act on.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { filterDisabledFromData, readViolations, type ViolationsData } from '../../violationsReader';
import { buildSuppressionsExportSnapshotStripHtml } from '../../views/configDashboardSuppressionsStrip';

/** A minimal export holding only the suppression aggregate under test. */
const exportWith = (suppressions: unknown) =>
  ({ violations: [], summary: { suppressions } }) as ViolationsData;

/** The collapsed variants share one contract: a muted line and no button. */
const assertCollapsed = (html: string, text: string) => {
  assert.ok(html.includes('strip collapsed'), html);
  assert.ok(html.includes(text), html);
  assert.ok(!html.includes('<button'), html);
};

describe('configDashboardSuppressionsStrip', () => {
  it('collapses when there is no violations.json', () => {
    assertCollapsed(buildSuppressionsExportSnapshotStripHtml(null), 'No violations.json yet');
  });

  it('collapses for zero totals and for exports without an aggregate', () => {
    const cases: ViolationsData[] = [
      exportWith({ total: 0 }),
      exportWith({ total: 0, byKind: { accepted: 0 } }),
      exportWith({}),
      exportWith(undefined),
      { violations: [] },
    ];
    for (const data of cases) {
      assertCollapsed(buildSuppressionsExportSnapshotStripHtml(data), '0 analyzer suppressions');
    }
  });

  it('shows the total and the accepted count beside the other kinds', () => {
    const html = buildSuppressionsExportSnapshotStripHtml(
      exportWith({ total: 7, byKind: { ignore: 2, ignoreForFile: 1, baseline: 0, accepted: 4 } }),
    );
    assert.ok(html.includes('Total <strong>7</strong>'), html);
    // Largest count first; a zero kind is still listed.
    assert.ok(html.includes('accepted 4 · ignore 2 · ignoreForFile 1 · baseline 0'), html);
    assert.ok(html.includes('data-command="openFindingsDashboard"'), html);
    assert.ok(!html.includes('strip collapsed'), html);
  });

  it('says so when a non-empty export has no by-kind breakdown', () => {
    const html = buildSuppressionsExportSnapshotStripHtml(exportWith({ total: 3 }));
    assert.ok(html.includes('Total <strong>3</strong>'), html);
    assert.ok(html.includes('No by-kind breakdown in this export.'), html);
  });

  // violations.json is a file in the workspace: its keys and values are untrusted.
  it('escapes kind names and drops counts that are not numbers', () => {
    const html = buildSuppressionsExportSnapshotStripHtml(
      exportWith({
        total: 2,
        byKind: { '<img src=x onerror="a()">&': 1, accepted: '<script>alert(1)</script>' },
      }),
    );
    assert.ok(!html.includes('<img'), html);
    assert.ok(!html.includes('<script'), html);
    assert.ok(html.includes('&lt;img src=x onerror=&quot;a()&quot;&gt;&amp; 1'), html);
    assert.ok(!html.includes('accepted'), html);
  });

  // End to end through the reader and the disabled-rule filter the dashboard applies.
  describe('from a violations.json on disk', () => {
    let root: string;
    beforeEach(() => {
      root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-strip-'));
      fs.mkdirSync(path.join(root, 'reports', '.saropa_lints'), { recursive: true });
    });
    afterEach(() => fs.rmSync(root, { recursive: true, force: true }));

    it('keeps the accepted count after a disabled rule is filtered out', () => {
      const data = {
        violations: [{ file: 'lib/a.dart', line: 1, rule: 'off_rule', message: 'm' }],
        summary: { suppressions: { total: 5, byKind: { ignore: 2, accepted: 3 } } },
      };
      fs.writeFileSync(
        path.join(root, 'reports', '.saropa_lints', 'violations.json'),
        JSON.stringify(data),
      );
      const read = readViolations(root);
      assert.ok(read, 'export was not read');
      const html = buildSuppressionsExportSnapshotStripHtml(
        filterDisabledFromData(read, new Set(['off_rule'])),
      );
      assert.ok(html.includes('Total <strong>5</strong>'), html);
      assert.ok(html.includes('accepted 3 · ignore 2'), html);
    });
  });
});
