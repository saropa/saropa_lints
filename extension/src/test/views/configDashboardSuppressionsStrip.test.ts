/**
 * Config Dashboard suppressions strip (export snapshot only; no vscode).
 *
 * Empty/zero variants collapse to a single muted line with no CTA per UX_UI_GUIDELINES §8.16
 * — the strip only earns a bordered band and an *Open Findings* CTA when there is something
 * to act on.
 */

import * as assert from 'assert';
import type { ViolationsData } from '../../violationsReader';
import { buildSuppressionsExportSnapshotStripHtml } from '../../views/configDashboardSuppressionsStrip';

describe('configDashboardSuppressionsStrip', () => {
  it('renders a collapsed line when no violations.json exists (no CTA)', () => {
    const html = buildSuppressionsExportSnapshotStripHtml(null);
    assert.ok(html.includes('strip collapsed'));
    assert.ok(html.includes('No <code>violations.json</code>'));
    // Collapsed empty state must not advertise an action — the user has nothing to open.
    assert.ok(!html.includes('data-command="openFindingsDashboard"'));
  });

  it('shows total, by-kind counts, and Findings CTA when export has suppressions', () => {
    const data: ViolationsData = {
      violations: [],
      summary: {
        suppressions: { total: 12, byKind: { ignore: 4, ignoreForFile: 8 } },
      },
    };
    const html = buildSuppressionsExportSnapshotStripHtml(data);
    assert.ok(html.includes('Total'));
    assert.ok(html.includes('12'));
    assert.ok(html.includes('ignore'));
    assert.ok(html.includes('openFindingsDashboard'));
    assert.ok(!html.includes('strip collapsed'));
  });

  it('renders a collapsed line for zero-suppression exports (no CTA)', () => {
    const data: ViolationsData = { violations: [], summary: { suppressions: { total: 0 } } };
    const html = buildSuppressionsExportSnapshotStripHtml(data);
    assert.ok(html.includes('strip collapsed'));
    assert.ok(html.includes('0 analyzer suppressions'));
    assert.ok(!html.includes('data-command="openFindingsDashboard"'));
  });
});
