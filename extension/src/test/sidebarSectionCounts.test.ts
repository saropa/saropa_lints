/**
 * Tests for {@link buildSidebarSectionCountMap}: violation-derived sidebar counts must not
 * depend on lint “integration enabled” (that flag lives elsewhere). These cases guard
 * regressions where an early return wiped counts whenever `saropaLints.enabled` was false.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { buildSidebarSectionCountMap } from '../sidebarSectionCounts';
import type { ViolationsData } from '../violationsReader';

describe('buildSidebarSectionCountMap', () => {
  it('returns empty map when workspace root is undefined', () => {
    const m = buildSidebarSectionCountMap({
      workspaceRoot: undefined,
      tier: 'recommended',
      violations: null,
      todosMarkerCount: undefined,
      driftIssueCount: undefined,
      vibrancyPackageCount: 0,
    });
    assert.strictEqual(m.size, 0);
  });

  it('does not set violation-derived keys when violations input is null', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-sidebar-'));
    try {
      const m = buildSidebarSectionCountMap({
        workspaceRoot: dir,
        tier: 'recommended',
        violations: null,
        todosMarkerCount: undefined,
        driftIssueCount: 2,
        vibrancyPackageCount: 0,
      });
      assert.strictEqual(m.get('sidebar.showIssues'), undefined);
      assert.strictEqual(m.get('sidebar.showDriftAdvisor'), 2);
      assert.strictEqual(m.get('sidebar.showRulePacks'), 0);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });

  it('sets Issues / Summary counts from violations even without legacy integration gate', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-sidebar-'));
    try {
      const data: ViolationsData = {
        violations: [
          { file: 'lib/a.dart', line: 1, rule: 'test_rule', message: 'x' },
          { file: 'lib/b.dart', line: 2, rule: 'test_rule', message: 'y' },
        ],
        summary: { totalViolations: 2 },
        config: { enabledRuleCount: 42 },
      };
      const m = buildSidebarSectionCountMap({
        workspaceRoot: dir,
        tier: 'recommended',
        violations: data,
        todosMarkerCount: 5,
        driftIssueCount: undefined,
        vibrancyPackageCount: 3,
      });
      assert.strictEqual(m.get('sidebar.showIssues'), 2);
      assert.strictEqual(m.get('sidebar.showSummary'), 2);
      assert.strictEqual(m.get('sidebar.showFileRisk'), 2);
      assert.strictEqual(m.get('sidebar.showPackageVibrancy'), 3);
      assert.strictEqual(m.get('sidebar.showTodosAndHacks'), 5);
      assert.strictEqual(m.get('sidebar.showConfig'), 42);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
});
