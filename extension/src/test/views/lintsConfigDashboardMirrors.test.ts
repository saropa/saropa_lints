/**
 * Snapshot-style tests for `buildSidebarMirrorPanelsHtml`: verifies the HTML
 * mirrors key violation export fields (suppression breakdown, OWASP hints) so
 * dashboard webviews stay aligned with `ViolationsData` shape changes.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'assert';
import type { ViolationsData } from '../../violationsReader';
import { buildSidebarMirrorPanelsHtml } from '../../views/lintsConfigDashboardMirrors';

describe('lintsConfigDashboardMirrors', () => {
  it('renders suppression totals and OWASP count from export-shaped data', () => {
    const data: ViolationsData = {
      violations: [
        { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'm', owasp: { web: ['W1'] } },
        { file: 'lib/b.dart', line: 2, rule: 'r2', message: 'm2' },
      ],
      summary: {
        suppressions: { total: 5, byKind: { ignore: 2, ignoreForFile: 1, baseline: 2 } },
      },
    };
    const html = buildSidebarMirrorPanelsHtml(data);
    assert.ok(html.includes('Total suppressed in export'));
    assert.ok(html.includes('5'));
    assert.ok(html.includes('ignore'));
    assert.ok(html.includes('1 violation(s) in this export carry OWASP'));
    assert.ok(html.includes('Security posture (OWASP signal)'));
    assert.ok(html.includes('Suppressions (export snapshot)'));
  });

  // The strip is the only visible surface for accepted findings.
  it('lists the accepted kind beside the other suppression kinds', () => {
    const html = buildSidebarMirrorPanelsHtml({
      violations: [],
      summary: {
        suppressions: { total: 7, byKind: { ignore: 2, ignoreForFile: 1, baseline: 1, accepted: 3 } },
      },
    });
    assert.ok(html.includes('Total suppressed in export: <strong>7</strong>'));
    assert.ok(html.includes('(ignore 2, ignore_for_file 1, baseline 1, accepted 3)'));
  });

  // Exports written before the accepted kind existed must read as zero, not "undefined".
  it('shows accepted 0 when the export has no accepted kind', () => {
    const html = buildSidebarMirrorPanelsHtml({
      violations: [],
      summary: { suppressions: { total: 1, byKind: { ignore: 1 } } },
    });
    assert.ok(html.includes('accepted 0'));
  });

  it('lists top file risk paths', () => {
    const data: ViolationsData = {
      violations: [
        { file: 'lib/hot.dart', line: 1, rule: 'x', message: 'a', impact: 'critical' },
        { file: 'lib/hot.dart', line: 2, rule: 'y', message: 'b', impact: 'high' },
        { file: 'lib/cool.dart', line: 1, rule: 'z', message: 'c', impact: 'low' },
      ],
    };
    const html = buildSidebarMirrorPanelsHtml(data);
    assert.ok(html.includes('lib/hot.dart'));
    assert.ok(html.includes('File risk (top files)'));
  });
});
